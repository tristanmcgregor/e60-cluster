#include "clustervideoitem.h"
#include "streamworker.h"

#include <QQuickWindow>
#include <QSGSimpleTextureNode>
#include <QTimerEvent>

namespace {
const int kStaleMs = 2000;
}

ClusterVideoItem::ClusterVideoItem(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, true);
    qRegisterMetaType<QImage>("QImage");

    m_worker = new StreamWorker;
    m_worker->moveToThread(&m_thread);
    connect(&m_thread, &QThread::finished, m_worker, &QObject::deleteLater);
    connect(this, &ClusterVideoItem::endpointChanged, m_worker, &StreamWorker::configure, Qt::QueuedConnection);
    connect(m_worker, &StreamWorker::frameReady, this, &ClusterVideoItem::onFrame, Qt::QueuedConnection);
    connect(m_worker, &StreamWorker::connectionChanged, this, &ClusterVideoItem::onConnected, Qt::QueuedConnection);
    m_thread.setObjectName(QStringLiteral("ClusterVideo"));
    m_thread.start();
}

ClusterVideoItem::~ClusterVideoItem()
{
    QMetaObject::invokeMethod(m_worker, "stop", Qt::BlockingQueuedConnection);
    m_thread.quit();
    m_thread.wait(2000);
}

void ClusterVideoItem::setHost(const QString &host)
{
    if (host == m_host) return;
    m_host = host;
    emit hostChanged();
    restartWorker();
}

void ClusterVideoItem::setPort(int port)
{
    if (port == m_port) return;
    m_port = port;
    emit portChanged();
    restartWorker();
}

void ClusterVideoItem::setSourceRect(const QRect &rect)
{
    if (rect == m_sourceRect) return;
    m_sourceRect = rect;
    emit sourceRectChanged();
    restartWorker();
}

void ClusterVideoItem::restartWorker()
{
    emit endpointChanged(m_host, m_port, m_sourceRect);
}

void ClusterVideoItem::onConnected(bool connected)
{
    if (connected == m_connected) return;
    m_connected = connected;
    emit connectedChanged();
}

void ClusterVideoItem::onFrame(const QImage &frame)
{
    {
        QMutexLocker lock(&m_frameLock);
        m_frame = frame;
        m_frameDirty = true;
    }
    ++m_framesDecoded;
    emit framesDecodedChanged();
    if (!m_streaming) {
        m_streaming = true;
        emit streamingChanged();
    }
    if (m_staleTimer) killTimer(m_staleTimer);
    m_staleTimer = startTimer(kStaleMs);
    update();
}

void ClusterVideoItem::timerEvent(QTimerEvent *event)
{
    if (event->timerId() != m_staleTimer)
        return QQuickItem::timerEvent(event);
    killTimer(m_staleTimer);
    m_staleTimer = 0;
    if (m_streaming) {
        m_streaming = false;
        emit streamingChanged();
    }
}

QSGNode *ClusterVideoItem::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *)
{
    auto *node = static_cast<QSGSimpleTextureNode *>(oldNode);
    QImage frame;
    {
        QMutexLocker lock(&m_frameLock);
        if (m_frameDirty) {
            frame = m_frame;
            m_frameDirty = false;
        }
    }
    if (!frame.isNull()) {
        if (!node) {
            node = new QSGSimpleTextureNode;
            node->setOwnsTexture(true);
            node->setFiltering(QSGTexture::Linear);
        }
        node->setTexture(window()->createTextureFromImage(frame));
    }
    if (node)
        node->setRect(boundingRect());
    return node;
}
