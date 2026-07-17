package com.fongmi.android.tv.player;

import static androidx.media3.common.Player.COMMAND_SET_SPEED_AND_PITCH;
import static androidx.media3.exoplayer.DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON;
import static androidx.media3.exoplayer.DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.SurfaceTexture;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.MediaControllerCompat;
import android.support.v4.media.session.MediaSessionCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.text.TextUtils;
import android.view.Surface;
import android.view.TextureView;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.media3.common.AudioAttributes;
import androidx.media3.common.C;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.common.Tracks;
import androidx.media3.common.VideoSize;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.drm.FrameworkMediaDrm;
import androidx.media3.exoplayer.util.EventLogger;
import androidx.media3.ui.PlayerView;

import com.bumptech.glide.request.transition.Transition;
import com.fongmi.android.tv.App;
import com.fongmi.android.tv.BuildConfig;
import com.fongmi.android.tv.Constant;
import com.fongmi.android.tv.R;
import com.fongmi.android.tv.Setting;
import com.fongmi.android.tv.bean.Danmaku;
import com.fongmi.android.tv.bean.Drm;
import com.fongmi.android.tv.bean.Result;
import com.fongmi.android.tv.bean.Sub;
import com.fongmi.android.tv.bean.Track;
import com.fongmi.android.tv.event.ActionEvent;
import com.fongmi.android.tv.event.ErrorEvent;
import com.fongmi.android.tv.event.PlayerEvent;
import com.fongmi.android.tv.impl.CustomTarget;
import com.fongmi.android.tv.impl.ParseCallback;
import com.fongmi.android.tv.impl.SessionCallback;
import com.fongmi.android.tv.player.danmaku.DanPlayer;
import com.fongmi.android.tv.player.exo.ErrorMsgProvider;
import com.fongmi.android.tv.player.exo.ExoUtil;
import com.fongmi.android.tv.player.exo.TrackUtil;
import com.fongmi.android.tv.server.Server;
import com.fongmi.android.tv.server.process.Hls;
import com.fongmi.android.tv.utils.FileUtil;
import com.fongmi.android.tv.utils.ImgUtil;
import com.fongmi.android.tv.utils.Notify;
import com.fongmi.android.tv.utils.ResUtil;
import com.fongmi.android.tv.utils.UrlUtil;
import com.fongmi.android.tv.utils.Util;
import com.github.catvod.utils.Path;
import com.google.common.net.HttpHeaders;
import com.orhanobut.logger.Logger;

import dev.jdtech.mpv.MPVLib;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Formatter;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import master.flame.danmaku.ui.widget.DanmakuView;
import tv.danmaku.ijk.media.player.IjkMediaPlayer;

public class Players implements Player.Listener, ParseCallback {

    private static final String TAG = Players.class.getSimpleName();

    public static final int SOFT = 0;
    public static final int HARD = 1;

    private final ErrorMsgProvider provider;
    private final AudioManager audioManager;
    private final StringBuilder builder;
    private final Formatter formatter;
    private final Runnable runnable;

    private Map<String, String> headers;
    private MediaSessionCompat session;
    private List<Danmaku> danmakus;
    private IjkMediaPlayer ijkPlayer;
    private ExoPlayer exoPlayer;
    private DanPlayer danPlayer;
    private ParseJob parseJob;
    private TextureView textureView;
    private Surface surface;
    private PlayerView view;
    private VideoSize size;
    private List<Sub> subs;
    private String format;
    private String tag;
    private String key;
    private String url;
    private String playUrl;
    private Drm drm;
    private Sub sub;

    private boolean initTrack;
    private boolean mpvCreated;
    private boolean mpvLoaded;
    private boolean mpvPaused;
    private boolean mpvEnded;
    private int decode;
    private int player;
    private int retry;

    private final MPVLib.Observer mpvObserver = new MPVLib.Observer() {
        @Override
        public void onEvent(int event) {
            handleMpvEvent(event);
        }

        @Override
        public void onProperty(String name, boolean value) {
            if ("pause".equals(name)) {
                mpvPaused = value;
                PlayerEvent.playing(tag);
                ActionEvent.update();
            }
        }
    };

    public static Players create(Activity activity) {
        Players player = new Players(activity);
        Server.get().setPlayer(player);
        return player;
    }

    private Players(Activity activity) {
        decode = HARD;
        builder = new StringBuilder();
        provider = new ErrorMsgProvider();
        runnable = () -> ErrorEvent.timeout(tag);
        formatter = new Formatter(builder, Locale.getDefault());
        audioManager = (AudioManager) activity.getSystemService(Context.AUDIO_SERVICE);
        createSession(activity);
    }

    private void createSession(Activity activity) {
        session = new MediaSessionCompat(activity, "TV");
        session.setCallback(SessionCallback.create(this));
        session.setFlags(MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS | MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS);
        session.setSessionActivity(PendingIntent.getActivity(App.get(), 0, new Intent(App.get(), activity.getClass()), PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));
        MediaControllerCompat.setMediaController(activity, session.getController());
    }

    private void releaseSession() {
        session.setActive(false);
        session.release();
    }

    public void init(PlayerView view) {
        releasePlayer();
        setPlayer(view);
        setMediaItem();
    }

    private void setPlayer(PlayerView view) {
        this.view = view;
        this.player = Setting.getPlayer();
        if (Setting.isIjk()) {
            setIjkPlayer(view);
            return;
        } else if (Setting.isMpv()) {
            setMpvPlayer(view);
            return;
        }
        removeTextureView();
        view.setVisibility(View.VISIBLE);
        exoPlayer = new ExoPlayer.Builder(App.get()).setLoadControl(ExoUtil.buildLoadControl()).setTrackSelector(ExoUtil.buildTrackSelector()).setRenderersFactory(ExoUtil.buildRenderersFactory(isHard() ? EXTENSION_RENDERER_MODE_ON : EXTENSION_RENDERER_MODE_PREFER)).setMediaSourceFactory(ExoUtil.buildMediaSourceFactory()).build();
        if (BuildConfig.DEBUG) exoPlayer.addAnalyticsListener(new EventLogger());
        exoPlayer.setAudioAttributes(AudioAttributes.DEFAULT, true);
        exoPlayer.setHandleAudioBecomingNoisy(true);
        exoPlayer.setPlayWhenReady(true);
        exoPlayer.addListener(this);
        view.setPlayer(exoPlayer);
    }

    private void setIjkPlayer(PlayerView view) {
        try {
            view.setPlayer(null);
            view.setVisibility(View.INVISIBLE);
            setTextureView(view);
            ijkPlayer = new IjkMediaPlayer();
            ijkPlayer.setEventListener(new IjkMediaPlayer.EventListener() {
                @Override
                public void onPrepared() {
                    removeTimeoutCheck();
                    PlayerEvent.state(tag, Player.STATE_READY);
                    PlayerEvent.playing(tag);
                    ActionEvent.update();
                    setPlaybackState(PlaybackStateCompat.STATE_PLAYING);
                }

                @Override
                public void onCompletion() {
                    PlayerEvent.state(tag, Player.STATE_ENDED);
                    setPlaybackState(PlaybackStateCompat.STATE_STOPPED);
                }

                @Override
                public void onError() {
                    ErrorEvent.extract(tag, "IJK player error");
                }
            });
            ijkPlayer.f(0, "mediacodec");
            ijkPlayer.f(1, "start-on-prepared");
            if (surface != null) ijkPlayer.h(surface);
        } catch (Throwable e) {
            Logger.t(TAG).e(e, "IJK init failed");
            Setting.putPlayer(Setting.PLAYER_EXO);
            setPlayer(view);
        }
    }

    private void setMpvPlayer(PlayerView view) {
        try {
            if (!MPVLib.isAvailable()) throw new UnsatisfiedLinkError("MPV native library unavailable");
            view.setPlayer(null);
            view.setVisibility(View.INVISIBLE);
            setTextureView(view);
            MPVLib.create(App.get());
            MPVLib.setOptionString("vo", "gpu");
            MPVLib.setOptionString("hwdec", isHard() ? "mediacodec-copy" : "no");
            MPVLib.setOptionString("force-window", "no");
            MPVLib.addObserver(mpvObserver);
            MPVLib.observeProperty("pause", MPVLib.MPV_FORMAT_FLAG);
            MPVLib.observeProperty("duration", MPVLib.MPV_FORMAT_DOUBLE);
            MPVLib.observeProperty("time-pos", MPVLib.MPV_FORMAT_DOUBLE);
            MPVLib.init();
            mpvCreated = true;
            mpvLoaded = false;
            mpvPaused = false;
            mpvEnded = false;
            if (surface != null) MPVLib.attachSurface(surface);
        } catch (Throwable e) {
            Logger.t(TAG).e(e, "MPV init failed");
            Setting.putPlayer(Setting.PLAYER_EXO);
            setPlayer(view);
        }
    }

    private void setTextureView(PlayerView view) {
        if (textureView != null) return;
        ViewGroup parent = (ViewGroup) view.getParent();
        textureView = new TextureView(view.getContext());
        textureView.setLayoutParams(new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        textureView.setSurfaceTextureListener(new TextureView.SurfaceTextureListener() {
            @Override
            public void onSurfaceTextureAvailable(@NonNull SurfaceTexture texture, int width, int height) {
                surface = new Surface(texture);
                if (ijkPlayer != null) ijkPlayer.h(surface);
                if (mpvCreated) MPVLib.attachSurface(surface);
            }

            @Override
            public void onSurfaceTextureSizeChanged(@NonNull SurfaceTexture texture, int width, int height) {
            }

            @Override
            public boolean onSurfaceTextureDestroyed(@NonNull SurfaceTexture texture) {
                if (ijkPlayer != null) ijkPlayer.h(null);
                if (mpvCreated) MPVLib.detachSurface();
                if (surface != null) surface.release();
                surface = null;
                return true;
            }

            @Override
            public void onSurfaceTextureUpdated(@NonNull SurfaceTexture texture) {
            }
        });
        parent.addView(textureView, 0);
    }

    private void removeTextureView() {
        if (textureView != null && textureView.getParent() instanceof ViewGroup) ((ViewGroup) textureView.getParent()).removeView(textureView);
        if (surface != null) surface.release();
        textureView = null;
        surface = null;
    }

    public void setDanmakuView(DanmakuView view) {
        danPlayer = new DanPlayer();
        danPlayer.setPlayer(this);
        danPlayer.setView(view);
    }

    public ExoPlayer get() {
        return exoPlayer;
    }

    public MediaSessionCompat getSession() {
        return session;
    }

    public List<Danmaku> getDanmakus() {
        return danmakus;
    }

    public String getUrl() {
        return url;
    }

    public Map<String, String> getHeaders() {
        return headers == null ? new HashMap<>() : headers;
    }

    public void setSub(Sub sub) {
        this.sub = sub;
        setMediaItem();
    }

    public void setFormat(String format) {
        this.format = format;
        setMediaItem();
    }

    public String getKey() {
        return key != null ? key : url;
    }

    public void setKey(String key) {
        this.key = key;
    }

    public String getTag() {
        return tag;
    }

    public void setTag(String tag) {
        this.tag = tag;
    }

    public void reset() {
        removeTimeoutCheck();
        retry = 0;
    }

    public void clearMediaItems() {
        if (exoPlayer != null) exoPlayer.clearMediaItems();
    }

    public void clear() {
        danmakus = null;
        headers = null;
        format = null;
        subs = null;
        drm = null;
        url = null;
        playUrl = null;
    }

    public String stringToTime(long time) {
        return Util.format(builder, formatter, time);
    }

    public int getVideoWidth() {
        return size == null ? 0 : size.width;
    }

    public int getVideoHeight() {
        return size == null ? 0 : size.height;
    }

    public float getSpeed() {
        if (ijkPlayer != null) return ijkPlayer.a() <= 0 ? 1.0f : ijkPlayer.a();
        if (mpvCreated) {
            Double speed = MPVLib.getPropertyDouble("speed");
            return speed == null ? 1.0f : speed.floatValue();
        }
        return exoPlayer == null ? 1.0f : exoPlayer.getPlaybackParameters().speed;
    }

    public long getPosition() {
        if (ijkPlayer != null) return ijkPlayer.getCurrentPosition();
        if (mpvCreated) {
            Double position = MPVLib.getPropertyDouble("time-pos");
            return position == null ? C.TIME_UNSET : (long) (position * 1000);
        }
        return exoPlayer == null ? C.TIME_UNSET : exoPlayer.getCurrentPosition();
    }

    public long getDuration() {
        if (ijkPlayer != null) return ijkPlayer.getDuration();
        if (mpvCreated) {
            Double duration = MPVLib.getPropertyDouble("duration");
            return duration == null ? -1 : (long) (duration * 1000);
        }
        return exoPlayer == null ? -1 : exoPlayer.getDuration();
    }

    public long getBuffered() {
        if (ijkPlayer != null || mpvCreated) return getPosition();
        return exoPlayer == null ? 0 : exoPlayer.getBufferedPosition();
    }

    public boolean haveTrack(int type) {
        return exoPlayer != null && TrackUtil.count(exoPlayer.getCurrentTracks(), type) > 0;
    }

    public boolean haveDanmaku() {
        if (danmakus != null) for (Danmaku danmaku : danmakus) if (danmaku.isSelected()) return true;
        return false;
    }

    public boolean canSetOpening(long position, long duration) {
        return position > 0 && duration > 0 && position <= Constant.getOpEdLimit(duration);
    }

    public boolean canSetEnding(long position, long duration) {
        return position > 0 && duration > 0 && duration - position <= Constant.getOpEdLimit(duration);
    }

    public boolean isPlaying() {
        if (ijkPlayer != null) return ijkPlayer.isPrepared() && ijkPlayer.isPlaying();
        if (mpvCreated) return mpvLoaded && !mpvPaused && !mpvEnded;
        return exoPlayer != null && exoPlayer.isPlaying();
    }

    public boolean isEnded() {
        if (mpvCreated) return mpvEnded;
        return exoPlayer != null && exoPlayer.getPlaybackState() == Player.STATE_ENDED;
    }

    public boolean isIdle() {
        if (ijkPlayer != null) return !ijkPlayer.isPrepared();
        if (mpvCreated) return !mpvLoaded;
        return exoPlayer != null && exoPlayer.getPlaybackState() == Player.STATE_IDLE;
    }

    public boolean isEmpty() {
        return TextUtils.isEmpty(getUrl());
    }

    public boolean isLive() {
        return getDuration() < TimeUnit.MINUTES.toMillis(1) || (exoPlayer != null && exoPlayer.isCurrentMediaItemLive());
    }

    public boolean isVod() {
        return getDuration() > TimeUnit.MINUTES.toMillis(1) && (exoPlayer == null || !exoPlayer.isCurrentMediaItemLive());
    }

    public boolean isHard() {
        return decode == HARD;
    }

    public boolean isPortrait() {
        return getVideoHeight() > getVideoWidth();
    }

    public boolean isLandscape() {
        return getVideoWidth() > getVideoHeight();
    }

    public String getSizeText() {
        return getVideoWidth() == 0 && getVideoHeight() == 0 ? "" : getVideoWidth() + " x " + getVideoHeight();
    }

    public String getSpeedText() {
        return String.format(Locale.getDefault(), "%.2f", getSpeed());
    }

    public String getDecodeText() {
        return ResUtil.getStringArray(R.array.select_decode)[decode];
    }

    public String setSpeed(float speed) {
        if (ijkPlayer != null) {
            ijkPlayer.g(speed);
            return getSpeedText();
        }
        if (mpvCreated) {
            MPVLib.setPropertyDouble("speed", (double) speed);
            return getSpeedText();
        }
        if (exoPlayer == null || !exoPlayer.isCommandAvailable(COMMAND_SET_SPEED_AND_PITCH)) return getSpeedText();
        exoPlayer.setPlaybackParameters(exoPlayer.getPlaybackParameters().withSpeed(speed));
        return getSpeedText();
    }

    public String addSpeed() {
        float speed = getSpeed();
        float addon = speed >= 2 ? 1f : 0.25f;
        speed = speed >= 5 ? 0.25f : Math.min(speed + addon, 5.0f);
        return setSpeed(speed);
    }

    public String addSpeed(float value) {
        float speed = getSpeed();
        speed = Math.min(speed + value, 5);
        return setSpeed(speed);
    }

    public String subSpeed(float value) {
        float speed = getSpeed();
        speed = Math.max(speed - value, 0.25f);
        return setSpeed(speed);
    }

    public String toggleSpeed() {
        float speed = getSpeed();
        speed = speed == 1 ? Setting.getSpeed() : 1;
        return setSpeed(speed);
    }

    public void toggleDecode() {
        decode = isHard() ? SOFT : HARD;
        init(view);
    }

    public String getPositionTime(long time) {
        time = getPosition() + time;
        if (time > getDuration()) time = getDuration();
        else if (time < 0) time = 0;
        return stringToTime(time);
    }

    public String getDurationTime() {
        long time = getDuration();
        if (time < 0) time = 0;
        return stringToTime(time);
    }

    public void seek(long time) {
        seekTo(getPosition() + time);
    }

    public void seekTo(long time) {
        if (ijkPlayer != null) ijkPlayer.seekTo(time);
        if (mpvCreated) MPVLib.command(new String[]{"seek", String.valueOf(time / 1000.0d), "absolute"});
        if (exoPlayer != null) exoPlayer.seekTo(time);
        if (danPlayer != null) danPlayer.seekTo(time);
    }

    public void seekToDefaultPosition() {
        if (ijkPlayer != null || mpvCreated) {
            seekTo(0);
            return;
        }
        if (exoPlayer != null) exoPlayer.seekToDefaultPosition();
        prepare();
    }

    public void prepare() {
        if (ijkPlayer != null) ijkPlayer._prepareAsync();
        if (exoPlayer != null) exoPlayer.prepare();
    }

    public void play() {
        if (ijkPlayer != null) ijkPlayer.i();
        if (mpvCreated) MPVLib.setPropertyBoolean("pause", false);
        if (exoPlayer != null) exoPlayer.play();
        if (danPlayer != null) danPlayer.play();
    }

    public void pause() {
        if (ijkPlayer != null) ijkPlayer.b();
        if (mpvCreated) MPVLib.setPropertyBoolean("pause", true);
        if (exoPlayer != null) exoPlayer.pause();
        if (danPlayer != null) danPlayer.pause();
    }

    public void stop() {
        if (ijkPlayer != null) ijkPlayer.j();
        if (mpvCreated) MPVLib.command(new String[]{"stop"});
        if (exoPlayer != null) exoPlayer.stop();
        if (danPlayer != null) danPlayer.stop();
        stopParse();
    }

    public void release() {
        stopParse();
        releasePlayer();
        releaseSession();
        removeTimeoutCheck();
        Server.get().setPlayer(null);
        App.execute(() -> Source.get().stop());
    }

    private void releasePlayer() {
        if (exoPlayer != null) exoPlayer.release();
        if (ijkPlayer != null) ijkPlayer.c();
        if (mpvCreated) {
            MPVLib.removeObserver(mpvObserver);
            MPVLib.command(new String[]{"stop"});
            MPVLib.detachSurface();
            MPVLib.destroy();
        }
        if (danPlayer != null) danPlayer.release();
        if (view != null) {
            view.setPlayer(null);
            view.setVisibility(View.VISIBLE);
        }
        removeTextureView();
        exoPlayer = null;
        ijkPlayer = null;
        mpvCreated = false;
        mpvLoaded = false;
        mpvPaused = false;
        mpvEnded = false;
    }

    private void removeTimeoutCheck() {
        App.removeCallbacks(runnable);
    }

    public void start(Result result, boolean useParse, long timeout) {
        if (result.getDrm() != null && !FrameworkMediaDrm.isCryptoSchemeSupported(result.getDrm().getUUID())) {
            ErrorEvent.drm(tag);
        } else if (result.hasMsg()) {
            ErrorEvent.extract(tag, result.getMsg());
        } else if (result.getParse() == 1 || result.getJx() == 1) {
            startParse(result, useParse);
        } else if (isIllegal(result.getRealUrl())) {
            ErrorEvent.url(tag);
        } else {
            setMediaItem(result, timeout);
        }
    }

    private void startParse(Result result, boolean useParse) {
        stopParse();
        drm = result.getDrm();
        subs = result.getSubs();
        format = result.getFormat();
        danmakus = result.getDanmaku();
        parseJob = ParseJob.create(this).start(result, useParse);
    }

    private void stopParse() {
        if (parseJob != null) parseJob.stop();
        parseJob = null;
    }

    private Map<String, String> checkUa(Map<String, String> headers) {
        for (Map.Entry<String, String> header : headers.entrySet()) if (HttpHeaders.USER_AGENT.equalsIgnoreCase(header.getKey())) return headers;
        headers.put(HttpHeaders.USER_AGENT, Setting.getUa().isEmpty() ? ExoUtil.getUa() : Setting.getUa());
        return headers;
    }

    private List<Sub> checkSub(List<Sub> subs) {
        if (subs == null) subs = this.subs = new ArrayList<>();
        if (sub == null || subs.contains(sub)) return subs;
        subs.add(0, sub);
        return subs;
    }

    public void setMediaItem() {
        if (url != null) setMediaItem(headers, url, format, drm, subs, danmakus, Constant.TIMEOUT_PLAY);
    }

    public void setMediaItem(String url) {
        setMediaItem(new HashMap<>(), url);
    }

    private void setMediaItem(Map<String, String> headers, String url) {
        setMediaItem(headers, url, format, drm, subs, danmakus, Constant.TIMEOUT_PLAY);
    }

    private void setMediaItem(Result result, long timeout) {
        setMediaItem(result.getHeader(), result.getRealUrl(), result.getFormat(), result.getDrm(), result.getSubs(), result.getDanmaku(), timeout);
    }

    private void setMediaItem(Map<String, String> headers, String url, String format, Drm drm, List<Sub> subs, List<Danmaku> danmakus, long timeout) {
        this.headers = checkUa(headers);
        this.url = url;
        this.playUrl = exoPlayer == null ? Hls.getUrl(url, this.headers, format) : url;
        this.format = format;
        this.drm = drm;
        this.subs = checkSub(subs);
        if (exoPlayer != null) exoPlayer.setMediaItem(ExoUtil.getMediaItem(this.headers, UrlUtil.uri(this.playUrl), this.format, this.drm, this.subs, decode));
        else if (ijkPlayer != null) setIjkMediaItem();
        else if (mpvCreated) setMpvMediaItem();
        Logger.t(TAG).d("headers=%s\nurl=%s\nplayUrl=%s\nformat=%s\ndrm=%s\nsubs=%s\ndanmakus=%s\ntimeout=%s", this.headers, url, this.playUrl, format, drm, this.subs, danmakus, timeout);
        if (danPlayer != null) setDanmaku(this.danmakus = danmakus);
        App.post(runnable, timeout);
        PlayerEvent.prepare(tag);
        session.setActive(true);
        initTrack = false;
        if (exoPlayer != null || ijkPlayer != null) prepare();
    }

    private void setIjkMediaItem() {
        try {
            ijkPlayer.d();
            if (surface != null) ijkPlayer.h(surface);
            ijkPlayer.f(0, "mediacodec");
            ijkPlayer.f(1, "start-on-prepared");
            ijkPlayer.e(App.get(), UrlUtil.uri(playUrl), headers);
        } catch (Throwable e) {
            Logger.t(TAG).e(e, "IJK set media failed");
            ErrorEvent.extract(tag, "IJK media error");
        }
    }

    private void setMpvMediaItem() {
        try {
            mpvLoaded = false;
            mpvPaused = false;
            mpvEnded = false;
            if (surface != null) MPVLib.attachSurface(surface);
            List<String> list = new ArrayList<>();
            for (Map.Entry<String, String> entry : headers.entrySet()) list.add(entry.getKey() + ": " + entry.getValue());
            if (!list.isEmpty()) MPVLib.setOptionString("http-header-fields", TextUtils.join(",", list));
            MPVLib.command(new String[]{"loadfile", playUrl, "replace"});
        } catch (Throwable e) {
            Logger.t(TAG).e(e, "MPV set media failed");
            ErrorEvent.extract(tag, "MPV media error");
        }
    }

    private void setDanmaku(List<Danmaku> items) {
        setDanmaku(items == null || items.isEmpty() ? Danmaku.empty() : items.get(0));
    }

    public void setDanmaku(Danmaku item) {
        danPlayer.setDanmaku(item);
        if (danmakus == null) danmakus = new ArrayList<>();
        if (!item.isEmpty() && !danmakus.contains(item)) danmakus.add(0, item);
        danmakus.forEach(d -> d.setSelected(d.getUrl().equals(item.getUrl())));
    }

    public void setDanmakuSize(float size) {
        if (danPlayer != null) danPlayer.setTextSize(size);
    }

    public void resetTrack() {
        if (exoPlayer != null) TrackUtil.reset(exoPlayer);
    }

    public void setTrack(List<Track> tracks) {
        if (exoPlayer != null && !tracks.isEmpty()) TrackUtil.setTrackSelection(exoPlayer, tracks);
    }

    private void handleMpvEvent(int event) {
        switch (event) {
            case MPVLib.MPV_EVENT_START_FILE:
                PlayerEvent.state(tag, Player.STATE_BUFFERING);
                setPlaybackState(PlaybackStateCompat.STATE_BUFFERING);
                break;
            case MPVLib.MPV_EVENT_END_FILE:
                mpvEnded = true;
                mpvLoaded = false;
                PlayerEvent.state(tag, Player.STATE_ENDED);
                setPlaybackState(PlaybackStateCompat.STATE_STOPPED);
                break;
            case MPVLib.MPV_EVENT_FILE_LOADED:
                removeTimeoutCheck();
                mpvLoaded = true;
                mpvPaused = false;
                mpvEnded = false;
                PlayerEvent.state(tag, Player.STATE_READY);
                PlayerEvent.playing(tag);
                ActionEvent.update();
                setPlaybackState(PlaybackStateCompat.STATE_PLAYING);
                break;
            case MPVLib.MPV_EVENT_VIDEO_RECONFIG:
                Integer width = MPVLib.getPropertyInt("width");
                Integer height = MPVLib.getPropertyInt("height");
                if (width != null && height != null) {
                    size = new VideoSize(width, height);
                    PlayerEvent.size(tag);
                }
                break;
        }
    }

    private void setPlaybackState(int state) {
        long actions = PlaybackStateCompat.ACTION_SEEK_TO | PlaybackStateCompat.ACTION_PLAY_PAUSE | PlaybackStateCompat.ACTION_SKIP_TO_NEXT | PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS;
        session.setPlaybackState(new PlaybackStateCompat.Builder().setActions(actions).setState(state, getPosition(), getSpeed()).build());
    }

    private boolean isIllegal(String url) {
        Uri uri = UrlUtil.uri(url);
        String host = UrlUtil.host(uri);
        String scheme = UrlUtil.scheme(uri);
        if ("data".equals(scheme)) return false;
        return scheme.isEmpty() || "file".equals(scheme) ? !Path.exists(url) : host.isEmpty();
    }

    public void setMetadata(String title, String artist, String artUri) {
        MediaMetadataCompat.Builder builder = new MediaMetadataCompat.Builder();
        builder.putString(MediaMetadataCompat.METADATA_KEY_TITLE, title);
        builder.putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist);
        builder.putString(MediaMetadataCompat.METADATA_KEY_ART_URI, artUri);
        builder.putString(MediaMetadataCompat.METADATA_KEY_ALBUM_ART_URI, artUri);
        builder.putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_ICON_URI, artUri);
        builder.putLong(MediaMetadataCompat.METADATA_KEY_DURATION, getDuration());
        putBitmap(builder, artUri);
    }

    private void putBitmap(MediaMetadataCompat.Builder builder, String artUri) {
        ImgUtil.load(artUri, new CustomTarget<>() {
            @Override
            public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                builder.putBitmap(MediaMetadataCompat.METADATA_KEY_ART, resource);
                session.setMetadata(builder.build());
                ActionEvent.update();
            }

            @Override
            public void onLoadFailed(@Nullable Drawable errorDrawable) {
                builder.putBitmap(MediaMetadataCompat.METADATA_KEY_ART, ((BitmapDrawable) errorDrawable).getBitmap());
                session.setMetadata(builder.build());
                ActionEvent.update();
            }
        });
    }

    public void share(Activity activity, CharSequence title) {
        try {
            if (isEmpty()) return;
            Bundle bundle = new Bundle();
            for (Map.Entry<String, String> entry : getHeaders().entrySet()) bundle.putString(entry.getKey(), entry.getValue());
            Intent intent = new Intent(Intent.ACTION_SEND);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            intent.putExtra(Intent.EXTRA_TEXT, getUrl());
            intent.putExtra("extra_headers", bundle);
            intent.putExtra("title", title);
            intent.putExtra("name", title);
            intent.setType("text/plain");
            activity.startActivity(Util.getChooser(intent));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void choose(Activity activity, CharSequence title) {
        try {
            if (isEmpty()) return;
            List<String> list = new ArrayList<>();
            for (Map.Entry<String, String> entry : getHeaders().entrySet()) list.addAll(Arrays.asList(entry.getKey(), entry.getValue()));
            Uri data = getUrl().startsWith("file://") || getUrl().startsWith("/") ? FileUtil.getShareUri(getUrl()) : Uri.parse(getUrl());
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            intent.setDataAndType(data, "video/*");
            intent.putExtra("title", title);
            intent.putExtra("return_result", isVod());
            intent.putExtra("headers", list.toArray(new String[0]));
            if (isVod()) intent.putExtra("position", (int) getPosition());
            activity.startActivityForResult(Util.getChooser(intent), 1001);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void checkData(Intent data) {
        try {
            if (data == null || data.getExtras() == null) return;
            int position = data.getExtras().getInt("position", 0);
            String endBy = data.getExtras().getString("end_by", "");
            if ("playback_completion".equals(endBy)) ActionEvent.next();
            if ("user".equals(endBy)) seekTo(position);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void onParseSuccess(Map<String, String> headers, String url, String from) {
        if (!TextUtils.isEmpty(from)) Notify.show(ResUtil.getString(R.string.parse_from, from));
        if (headers != null) headers.remove(HttpHeaders.RANGE);
        setMediaItem(headers, url);
    }

    @Override
    public void onParseError() {
        ErrorEvent.parse(tag);
    }

    @Override
    public void onEvents(@NonNull Player player, @NonNull Player.Events events) {
        if (!events.containsAny(Player.EVENT_TIMELINE_CHANGED, Player.EVENT_IS_PLAYING_CHANGED, Player.EVENT_POSITION_DISCONTINUITY, Player.EVENT_MEDIA_METADATA_CHANGED, Player.EVENT_PLAYBACK_STATE_CHANGED, Player.EVENT_PLAY_WHEN_READY_CHANGED, Player.EVENT_PLAYBACK_PARAMETERS_CHANGED, Player.EVENT_PLAYER_ERROR)) return;
        switch (player.getPlaybackState()) {
            case Player.STATE_IDLE:
                setPlaybackState(events.contains(Player.EVENT_PLAYER_ERROR) ? PlaybackStateCompat.STATE_ERROR : PlaybackStateCompat.STATE_NONE);
                break;
            case Player.STATE_READY:
                setPlaybackState(player.isPlaying() ? PlaybackStateCompat.STATE_PLAYING : PlaybackStateCompat.STATE_PAUSED);
                break;
            case Player.STATE_BUFFERING:
                setPlaybackState(PlaybackStateCompat.STATE_BUFFERING);
                break;
            case Player.STATE_ENDED:
                setPlaybackState(PlaybackStateCompat.STATE_STOPPED);
                break;
        }
    }

    @Override
    public void onIsPlayingChanged(boolean isPlaying) {
        if (isPlaying() && audioManager != null && audioManager.getMode() == AudioManager.MODE_IN_COMMUNICATION) pause();
        PlayerEvent.playing(tag);
        ActionEvent.update();
    }

    @Override
    public void onPlaybackStateChanged(int state) {
        if (danPlayer != null) danPlayer.check(state);
        PlayerEvent.state(tag, state);
    }

    @Override
    public void onVideoSizeChanged(@NonNull VideoSize videoSize) {
        this.size = videoSize;
        PlayerEvent.size(tag);
    }

    @Override
    public void onTracksChanged(@NonNull Tracks tracks) {
        if (tracks.isEmpty() || initTrack) return;
        setTrack(Track.find(getKey()));
        PlayerEvent.track(tag);
        initTrack = true;
    }

    @Override
    public void onPlayerError(@NonNull PlaybackException e) {
        if (++retry > 2) ErrorEvent.extract(tag, provider.get(e));
        else switch (e.errorCode) {
            case PlaybackException.ERROR_CODE_BEHIND_LIVE_WINDOW:
                seekToDefaultPosition();
                break;
            case PlaybackException.ERROR_CODE_DECODER_INIT_FAILED:
            case PlaybackException.ERROR_CODE_DECODER_QUERY_FAILED:
            case PlaybackException.ERROR_CODE_DECODING_FAILED:
                toggleDecode();
                break;
            case PlaybackException.ERROR_CODE_IO_UNSPECIFIED:
            case PlaybackException.ERROR_CODE_PARSING_CONTAINER_MALFORMED:
            case PlaybackException.ERROR_CODE_PARSING_MANIFEST_MALFORMED:
            case PlaybackException.ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED:
            case PlaybackException.ERROR_CODE_PARSING_MANIFEST_UNSUPPORTED:
                setFormat(ExoUtil.getMimeType(e.errorCode));
                break;
            default:
                ErrorEvent.extract(tag, provider.get(e));
                break;
        }
    }
}
