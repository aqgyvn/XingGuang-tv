package com.github.catvod.net;

import java.io.IOException;
import java.net.ConnectException;
import java.net.SocketTimeoutException;
import java.net.UnknownHostException;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeoutException;
import javax.net.ssl.SSLException;

/** Source failures must not be reported as a successful, empty catalogue. */
public final class SourceException extends IOException {
    public enum Kind { HTTP, EMPTY, HTML, FORMAT }

    public final Kind kind;
    public final int status;

    public SourceException(Kind kind, int status) {
        super(switch (kind) {
            case HTTP -> "资源接口返回 HTTP " + status;
            case EMPTY -> "资源接口返回空响应，请稍后重试";
            case HTML -> "资源接口返回网页而非资源数据，请检查接口地址或站点验证状态";
            case FORMAT -> "资源数据格式异常，请检查源配置或插件版本";
        });
        this.kind = kind;
        this.status = status;
    }

    public static String describe(Throwable error) {
        while (error instanceof ExecutionException && error.getCause() != null) error = error.getCause();
        if (error instanceof SourceException) return error.getMessage();
        if (error instanceof UnknownHostException) return "域名解析失败，请检查网络或 DNS 设置";
        if (error instanceof ConnectException) return "资源服务器连接失败，请稍后重试";
        if (error instanceof SocketTimeoutException || error instanceof TimeoutException) return "资源请求超时，请稍后重试";
        if (error instanceof SSLException) return "资源服务器 TLS 连接失败，请检查证书或设备时间";
        if (error instanceof IOException) return "资源传输中断，请重试";
        return "资源插件处理异常，请检查源配置或插件版本";
    }
}
