// Network + decode thread: reads [u32 BE length][Annex-B access unit] from the
// head unit, decodes with OpenH264, converts the cropped region to RGB.
#pragma once

#include <QByteArray>
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

signals:
    void frameReady(const QImage &frame);
    void connectionChanged(bool connected);

private slots:
    void onReadyRead();
    void onDisconnected();
    void reconnect();

private:
    bool openDecoder();
    void closeDecoder();
    void decode(const QByteArray &au);
    QImage toRgb(unsigned char *const planes[3], const int strides[2], int width, int height);

    QString m_host;
    int m_port = 0;
    QRect m_crop;
    QTcpSocket *m_socket = nullptr;
    QTimer *m_retry = nullptr;
    QByteArray m_buffer;
    ISVCDecoder *m_decoder = nullptr;
    bool m_stopping = false;
};
