package tv.danmaku.ijk.media.player;

import android.content.res.AssetFileDescriptor;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.os.ParcelFileDescriptor;
import android.text.TextUtils;
import android.util.Log;
import android.view.Surface;

import androidx.annotation.NonNull;

import com.fongmi.android.tv.App;

import java.io.FileDescriptor;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.lang.ref.WeakReference;
import java.util.Map;

import tv.danmaku.ijk.media.player.misc.IAndroidIO;
import tv.danmaku.ijk.media.player.misc.IMediaDataSource;

public final class IjkMediaPlayer {

    private static final String TAG = IjkMediaPlayer.class.getName();
    private static volatile boolean libraryLoaded;
    private static volatile boolean nativeInitialized;

    private final EventHandler eventHandler;
    private EventListener listener;
    private boolean prepared;
    private boolean screenOnWhilePlaying;
    private long mNativeAndroidIO;
    private long mNativeMediaDataSource;
    private long mNativeMediaPlayer;

    public IjkMediaPlayer() {
        loadLibrariesOnce();
        initNativeOnce();
        Looper looper = Looper.myLooper() != null ? Looper.myLooper() : Looper.getMainLooper();
        eventHandler = looper == null ? null : new EventHandler(this, looper);
        native_setup(new WeakReference<>(this));
    }

    private static void loadLibrariesOnce() {
        synchronized (IjkMediaPlayer.class) {
            if (libraryLoaded) return;
            System.loadLibrary("ijkffmpeg");
            System.loadLibrary("ijksdl");
            System.loadLibrary("ijkplayer");
            libraryLoaded = true;
        }
    }

    private static void initNativeOnce() {
        synchronized (IjkMediaPlayer.class) {
            if (nativeInitialized) return;
            native_init();
            nativeInitialized = true;
        }
    }

    public void setEventListener(EventListener listener) {
        this.listener = listener;
    }

    private native String _getAudioCodecInfo();

    private static native String _getColorFormatName(int mediaCodecColorFormat);

    private native int _getLoopCount();

    private native Bundle _getMediaMeta();

    private native float _getPropertyFloat(int property, float defaultValue);


    private native long _getPropertyLong(int property, long defaultValue);

    private native String _getVideoCodecInfo();

    private native void _pause();
    private native void _release();
    private native void _reset();
    private native void _setAndroidIOCallback(IAndroidIO androidIO);
    private native void _setDataSource(String path, String[] keys, String[] values);
    private native void _setDataSource(IMediaDataSource mediaDataSource);
    private native void _setDataSourceFd(int fd);
    private native void _setFrameAtTime(String path, long startTime, long endTime, int num, int definition);
    private native void _setLoopCount(int loopCount);
    private native void _setOption(int category, String name, long value);
    private native void _setOption(int category, String name, String value);
    private native void _setPropertyFloat(int property, float value);
    private native void _setPropertyLong(int property, long value);
    private native void _setStreamSelected(int stream, boolean selected);
    private native void _setVideoSurface(Surface surface);
    private native void _start();
    private native void _stop();
    private native void native_finalize();
    private static native void native_init();
    private native void native_message_loop(Object weakThiz);
    public static native void native_profileBegin(String libName);
    public static native void native_profileEnd();
    public static native void native_setLogLevel(int level);
    private native void native_setup(Object weakThiz);

    private static boolean onNativeInvoke(Object weakThiz, int what, Bundle args) {
        return false;
    }

    private static String onSelectCodec(Object weakThiz, String mimeType, int profile, int level) {
        return null;
    }

    private static void postEventFromNative(Object weakThiz, int what, int arg1, int arg2, Object obj) {
        if (weakThiz == null) return;
        IjkMediaPlayer player = (IjkMediaPlayer) ((WeakReference<?>) weakThiz).get();
        if (player == null || player.eventHandler == null) return;
        player.eventHandler.sendMessage(player.eventHandler.obtainMessage(what, arg1, arg2, obj));
    }

    public native void _prepareAsync();

    public float a() {
        return _getPropertyFloat(10003, 0.0f);
    }

    public void b() {
        _pause();
    }

    public void c() {
        prepared = false;
        listener = null;
        if (eventHandler != null) eventHandler.removeCallbacksAndMessages(null);
        _release();
    }

    public void d() {
        prepared = false;
        if (eventHandler != null) eventHandler.removeCallbacksAndMessages(null);
        _reset();
    }

    public void e(App app, Uri uri, Map<String, String> headers) throws IOException {
        String scheme = uri.getScheme();
        if ("file".equals(scheme) || TextUtils.isEmpty(scheme)) {
            _setDataSource("file".equals(scheme) ? uri.getPath() : uri.toString(), null, null);
            return;
        }
        if ("content".equals(scheme)) {
            if ("settings".equals(uri.getAuthority())) {
                uri = RingtoneManager.getActualDefaultRingtoneUri(app, RingtoneManager.getDefaultType(uri));
                if (uri == null) throw new FileNotFoundException("Failed to resolve default ringtone");
            }
            if (trySetContentSource(app, uri)) return;
        }
        setNetworkSource(uri.toString(), headers);
    }

    private boolean trySetContentSource(App app, Uri uri) throws IOException {
        AssetFileDescriptor afd = null;
        ParcelFileDescriptor pfd = null;
        try {
            afd = app.getContentResolver().openAssetFileDescriptor(uri, "r");
            if (afd == null) return false;
            FileDescriptor fd = afd.getFileDescriptor();
            pfd = ParcelFileDescriptor.dup(fd);
            _setDataSourceFd(pfd.getFd());
            return true;
        } catch (SecurityException e) {
            Log.d(TAG, "Couldn't open file on client side, trying server side", e);
            return false;
        } finally {
            if (pfd != null) pfd.close();
            if (afd != null) afd.close();
        }
    }

    private void setNetworkSource(String url, Map<String, String> headers) {
        if (headers == null || headers.isEmpty()) {
            _setDataSource(url, null, null);
            return;
        }
        String[] keys = new String[headers.size()];
        String[] values = new String[headers.size()];
        StringBuilder builder = new StringBuilder();
        int index = 0;
        for (Map.Entry<String, String> entry : headers.entrySet()) {
            keys[index] = entry.getKey();
            values[index] = entry.getValue();
            builder.append(entry.getKey()).append(":");
            if (!TextUtils.isEmpty(entry.getValue())) builder.append(entry.getValue());
            builder.append("\r\n");
            index++;
        }
        _setOption(1, "headers", builder.toString());
        _setOption(1, "protocol_whitelist", "async,cache,crypto,file,http,https,ijkhttphook,ijkinject,ijklivehook,ijklongurl,ijksegment,ijktcphook,pipe,rtp,tcp,tls,udp,ijkurlhook,data");
        _setDataSource(url, keys, values);
    }

    public void f(long value, String name) {
        _setOption(4, name, value);
    }

    @Override
    protected void finalize() throws Throwable {
        super.finalize();
        native_finalize();
    }

    public void g(float speed) {
        _setPropertyFloat(10003, speed);
    }

    public native int getAudioSessionId();
    public native long getCurrentPosition();
    public native long getDuration();

    public void h(Surface surface) {
        if (screenOnWhilePlaying && surface != null) Log.w(TAG, "setScreenOnWhilePlaying(true) is ineffective for Surface");
        _setVideoSurface(surface);
    }

    public void i() {
        _start();
    }

    public native boolean isPlaying();

    public boolean isPrepared() {
        return prepared;
    }

    public void j() {
        prepared = false;
        _stop();
    }

    public native void seekTo(long msec);
    public native void setVolume(float leftVolume, float rightVolume);

    private void dispatchPrepared() {
        if (prepared) return;
        prepared = true;
        if (listener != null) listener.onPrepared();
    }

    private void dispatchCompletion() {
        prepared = false;
        if (listener != null) listener.onCompletion();
    }

    private void dispatchError() {
        prepared = false;
        if (listener != null) listener.onError();
    }

    private static final class EventHandler extends Handler {
        private final WeakReference<IjkMediaPlayer> player;

        private EventHandler(IjkMediaPlayer player, Looper looper) {
            super(looper);
            this.player = new WeakReference<>(player);
        }

        @Override
        public void handleMessage(@NonNull Message msg) {
            IjkMediaPlayer player = this.player.get();
            if (player == null) {
                Log.w(TAG, "IjkMediaPlayer went away with unhandled events");
                return;
            }
            switch (msg.what) {
                case 1:
                    player.dispatchPrepared();
                    break;
                case 2:
                    player.dispatchCompletion();
                    break;
                case 100:
                    player.dispatchError();
                    break;
                case 200:
                    if (msg.arg1 == 3) player.dispatchPrepared();
                    break;
            }
        }
    }

    public interface EventListener {
        void onPrepared();

        void onCompletion();

        void onError();
    }
}
