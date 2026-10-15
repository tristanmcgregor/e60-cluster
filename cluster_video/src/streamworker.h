// Network + decode thread: reads [u32 BE length][Annex-B access unit] from the
// head unit, decodes with OpenH264, converts the cropped region to RGB. Sends 'K' back
// when the picture broke and it needs a keyframe.
#pragma once

#include <QByteArray>
#include <QMutex>
#include <QElapsedTimer>
#include <QImage>
#include <QObject>
#include <QRect>

class QTcpSocket;
class QTimer;
class ISVCDecoder;

class StreamWorker : public QObject
{
    Q_OBJECT
public:
    StreamWorker();
    ~StreamWorker() override;

public slots:
    void configure(const QString &host, int port, const QRect &crop);
    void stop();

public:
    // Called from the GUI thread after frameReady: the newest frame (null if already taken).
    QImage takeFrame();

signals:
    // At most one is ever queued: a frame decoded before the dash took the last one replaces it,
    // so a dash that draws slower than the video never piles frames up in memory.
    void frameReady();
    void connectionChanged(bool connected);

private slots:
    void onReadyRead();
    void onDisconnected();
    void reconnect();

private:
    bool openDecoder();
    void closeDecoder();
    void decode(const QByteArray &au, bool show);
    void askKeyframe();
    QImage toRgb(unsigned char *const planes[3], const int strides[2], int width, int height);

    QString m_host;
    int m_port = 0;
    QRect m_crop;
    QTcpSocket *m_socket = nullptr;
    QTimer *m_retry = nullptr;
    QByteArray m_buffer;
    ISVCDecoder *m_decoder = nullptr;
    bool m_stopping = false;
    bool m_waitIdr = true;
    QElapsedTimer m_askClock;

    QMutex m_outLock;
    QImage m_out;
    bool m_posted = false;      // frameReady sent, frame not taken yet
    int m_replaced = 0;         // frames the dash never drew because a newer one came first
    QElapsedTimer m_replacedClock;
};
