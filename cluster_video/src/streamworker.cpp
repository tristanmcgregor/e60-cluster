#include "streamworker.h"

#include <QDebug>
#include <QElapsedTimer>
#include <QTcpSocket>
#include <QTimer>
#include <QtEndian>

#include <wels/codec_api.h>

namespace {
const int kMaxUnitBytes = 1 << 20;     // matches ClusterVideo.MAX_AU_BYTES on the head unit
const int kRetryMs = 2000;
const qint64 kAskEveryMs = 500;        // 'K' to the head unit at most this often

inline bool hasIdr(const QByteArray &au)
{
    const uchar *p = reinterpret_cast<const uchar *>(au.constData());
    for (int i = 0; i + 3 < au.size(); ++i)
        if (p[i] == 0 && p[i + 1] == 0 && p[i + 2] == 1) {
            if ((p[i + 3] & 0x1f) == 5) return true;
            i += 2;
        }
    return false;
}

inline unsigned char clamp255(int v) { return static_cast<unsigned char>(v < 0 ? 0 : (v > 255 ? 255 : v)); }
}

StreamWorker::StreamWorker() = default;

StreamWorker::~StreamWorker()
{
    closeDecoder();
}

void StreamWorker::configure(const QString &host, int port, const QRect &crop)
{
    m_crop = crop;
    if (host == m_host && port == m_port && m_socket)
        return;
    m_host = host;
    m_port = port;
    if (!m_socket) {
        m_socket = new QTcpSocket(this);
        m_socket->setReadBufferSize(4 * 1024 * 1024);
        connect(m_socket, &QTcpSocket::readyRead, this, &StreamWorker::onReadyRead);
        connect(m_socket, &QTcpSocket::disconnected, this, &StreamWorker::onDisconnected);
        connect(m_socket, &QTcpSocket::connected, this, [this] {
            qInfo("[clustervideo] connected to %s:%d", qPrintable(m_host), m_port);
            emit connectionChanged(true);
        });
        connect(m_socket, static_cast<void (QAbstractSocket::*)(QAbstractSocket::SocketError)>(&QAbstractSocket::error),
                this, [this](QAbstractSocket::SocketError) { onDisconnected(); });
        m_retry = new QTimer(this);
        m_retry->setSingleShot(true);
        connect(m_retry, &QTimer::timeout, this, &StreamWorker::reconnect);
    }
    m_socket->abort();
    reconnect();
}

void StreamWorker::stop()
{
    m_stopping = true;
    if (m_retry) m_retry->stop();
    if (m_socket) m_socket->abort();
    closeDecoder();
}

void StreamWorker::reconnect()
{
    if (m_stopping || m_host.isEmpty() || m_port <= 0)
        return;
    if (m_socket->state() != QAbstractSocket::UnconnectedState)
        return;
    m_buffer.clear();
    closeDecoder();            // a new connection starts with SPS/PPS + IDR
    m_waitIdr = true;
    m_socket->connectToHost(m_host, static_cast<quint16>(m_port));
}

void StreamWorker::onDisconnected()
{
    emit connectionChanged(false);
    if (!m_stopping && !m_retry->isActive())
        m_retry->start(kRetryMs);
}

void StreamWorker::onReadyRead()
{
    m_buffer.append(m_socket->readAll());
    for (;;) {
        if (m_buffer.size() < 4)
            return;
        const quint32 len = qFromBigEndian<quint32>(reinterpret_cast<const uchar *>(m_buffer.constData()));
        if (len == 0 || len > static_cast<quint32>(kMaxUnitBytes)) {
            qWarning("[clustervideo] bad unit length %u, resyncing", len);
            m_socket->abort();
            return;
        }
        if (static_cast<quint32>(m_buffer.size()) < 4 + len)
            return;
        const QByteArray au = m_buffer.mid(4, static_cast<int>(len));
        m_buffer.remove(0, static_cast<int>(4 + len));
        // Behind (another whole unit already waiting): decode only, convert just the newest.
        bool more = false;
        if (m_buffer.size() >= 4) {
            const quint32 next = qFromBigEndian<quint32>(reinterpret_cast<const uchar *>(m_buffer.constData()));
            more = static_cast<quint32>(m_buffer.size()) >= 4 + next;
        }
        decode(au, !more);
    }
}

bool StreamWorker::openDecoder()
{
    if (m_decoder)
        return true;
    if (WelsCreateDecoder(&m_decoder) != 0 || !m_decoder) {
        qWarning("[clustervideo] WelsCreateDecoder failed");
        m_decoder = nullptr;
        return false;
    }
    SDecodingParam param;
    memset(&param, 0, sizeof(param));
    param.uiTargetDqLayer = static_cast<unsigned char>(-1);
    param.eEcActiveIdc = ERROR_CON_SLICE_COPY;
    param.sVideoProperty.eVideoBsType = VIDEO_BITSTREAM_DEFAULT;
    if (m_decoder->Initialize(&param) != 0) {
        qWarning("[clustervideo] decoder Initialize failed");
        WelsDestroyDecoder(m_decoder);
        m_decoder = nullptr;
        return false;
    }
    // Single-threaded on purpose: OpenH264's threaded decoder must be configured before
    // Initialize and crashes in DecodeFrameNoDelay otherwise; 800x480 does not need it.
    return true;
}

void StreamWorker::closeDecoder()
{
    if (!m_decoder)
        return;
    m_decoder->Uninitialize();
    WelsDestroyDecoder(m_decoder);
    m_decoder = nullptr;
}

// Draws nothing from a broken reference chain: after any decode error the last good picture stays
// up until a keyframe decodes cleanly, and the head unit is asked for one ('K') so that is soon.
void StreamWorker::decode(const QByteArray &au, bool show)
{
    if (!openDecoder())
        return;
    const bool idr = hasIdr(au);
    unsigned char *planes[3] = { nullptr, nullptr, nullptr };
    SBufferInfo info;
    memset(&info, 0, sizeof(info));
    const DECODING_STATE st = m_decoder->DecodeFrameNoDelay(
        reinterpret_cast<const unsigned char *>(au.constData()), au.size(), planes, &info);
    if (st != dsErrorFree) {
        if (!m_waitIdr || idr)
            qWarning("[clustervideo] decode error 0x%x, holding the picture until a keyframe", st);
        m_waitIdr = true;
        askKeyframe();
        return;
    }
    if (m_waitIdr) {
        if (!idr) {
            askKeyframe();
            return;
        }
        m_waitIdr = false;
    }
    if (info.iBufferStatus != 1 || !show)
        return;
    const int w = info.UsrData.sSystemBuffer.iWidth;
    const int h = info.UsrData.sSystemBuffer.iHeight;
    const int strides[2] = { info.UsrData.sSystemBuffer.iStride[0], info.UsrData.sSystemBuffer.iStride[1] };
    QImage frame = toRgb(planes, strides, w, h);
    if (!frame.isNull())
        emit frameReady(frame);
}

void StreamWorker::askKeyframe()
{
    if (!m_socket || m_socket->state() != QAbstractSocket::ConnectedState)
        return;
    if (m_askClock.isValid() && m_askClock.elapsed() < kAskEveryMs)
        return;
    m_askClock.start();
    m_socket->write("K", 1);
}

// BT.601 limited-range YUV 4:2:0 -> RGB32, only for the crop area (AA's margins are not shown).
QImage StreamWorker::toRgb(unsigned char *const planes[3], const int strides[2], int width, int height)
{
    QRect r = m_crop.isValid() ? m_crop.intersected(QRect(0, 0, width, height)) : QRect(0, 0, width, height);
    r.setLeft(r.left() & ~1);
    r.setTop(r.top() & ~1);
    if (r.isEmpty())
        return QImage();
    QImage out(r.width(), r.height(), QImage::Format_RGB32);
    for (int y = 0; y < r.height(); ++y) {
        const int sy = r.top() + y;
        const unsigned char *yRow = planes[0] + sy * strides[0];
        const unsigned char *uRow = planes[1] + (sy / 2) * strides[1];
        const unsigned char *vRow = planes[2] + (sy / 2) * strides[1];
        QRgb *dst = reinterpret_cast<QRgb *>(out.scanLine(y));
        for (int x = 0; x < r.width(); ++x) {
            const int sx = r.left() + x;
            const int c = 298 * (yRow[sx] - 16);
            const int d = uRow[sx / 2] - 128;
            const int e = vRow[sx / 2] - 128;
            dst[x] = qRgb(clamp255((c + 409 * e + 128) >> 8),
                          clamp255((c - 100 * d - 208 * e + 128) >> 8),
                          clamp255((c + 516 * d + 128) >> 8));
        }
    }
    return out;
}
