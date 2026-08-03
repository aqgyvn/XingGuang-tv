package com.fongmi.android.tv.player.exo;

import android.content.Context;
import android.media.MediaFormat;
import android.os.Build;
import android.os.Handler;

import androidx.annotation.RequiresApi;
import androidx.media3.common.C;
import androidx.media3.common.ColorInfo;
import androidx.media3.common.Format;
import androidx.media3.exoplayer.DecoderReuseEvaluation;
import androidx.media3.exoplayer.ExoPlaybackException;
import androidx.media3.exoplayer.FormatHolder;
import androidx.media3.exoplayer.Renderer;
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector;
import androidx.media3.exoplayer.video.MediaCodecVideoRenderer;
import androidx.media3.exoplayer.video.VideoRendererEventListener;

import java.util.ArrayList;

import io.github.anilbeesetti.nextlib.media3ext.ffdecoder.NextRenderersFactory;

final class ColorAwareRenderersFactory extends NextRenderersFactory {

    ColorAwareRenderersFactory(Context context) {
        super(context);
    }

    @Override
    protected void buildVideoRenderers(Context context, int extensionRendererMode, MediaCodecSelector mediaCodecSelector, boolean enableDecoderFallback, Handler eventHandler, VideoRendererEventListener eventListener, long allowedVideoJoiningTimeMs, ArrayList<Renderer> out) {
        super.buildVideoRenderers(context, extensionRendererMode, mediaCodecSelector, enableDecoderFallback, eventHandler, eventListener, allowedVideoJoiningTimeMs, out);
        for (int i = 0; i < out.size(); i++) {
            if (out.get(i).getClass() == MediaCodecVideoRenderer.class) {
                out.set(i, new ColorAwareVideoRenderer(context, mediaCodecSelector, allowedVideoJoiningTimeMs, enableDecoderFallback, eventHandler, eventListener));
            }
        }
    }

    private static final class ColorAwareVideoRenderer extends MediaCodecVideoRenderer {

        ColorAwareVideoRenderer(Context context, MediaCodecSelector mediaCodecSelector, long allowedVideoJoiningTimeMs, boolean enableDecoderFallback, Handler eventHandler, VideoRendererEventListener eventListener) {
            super(context, mediaCodecSelector, allowedVideoJoiningTimeMs, enableDecoderFallback, eventHandler, eventListener, MAX_DROPPED_VIDEO_FRAME_COUNT_TO_NOTIFY);
        }

        @Override
        protected DecoderReuseEvaluation onInputFormatChanged(FormatHolder holder) throws ExoPlaybackException {
            Format format = holder.format;
            ColorInfo colorInfo = format.colorInfo;
            if (isUnspecifiedEightBitSdr(colorInfo)) {
                holder.format = format.buildUpon().setColorInfo(colorInfo.buildUpon().setColorSpace(C.COLOR_SPACE_BT709).setColorRange(C.COLOR_RANGE_LIMITED).setColorTransfer(C.COLOR_TRANSFER_SDR).build()).build();
            }
            return super.onInputFormatChanged(holder);
        }

        @Override
        protected MediaFormat getMediaFormat(Format format, String codecMimeType, CodecMaxValues codecMaxValues, float codecOperatingRate, boolean deviceNeedsNoPostProcessWorkaround, int tunnelingAudioSessionId) {
            MediaFormat mediaFormat = super.getMediaFormat(format, codecMimeType, codecMaxValues, codecOperatingRate, deviceNeedsNoPostProcessWorkaround, tunnelingAudioSessionId);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && com.fongmi.android.tv.utils.Util.isMobile() && shouldRequestSdrToneMapping(format.colorInfo)) {
                requestSdrToneMapping(mediaFormat);
            }
            return mediaFormat;
        }

        @RequiresApi(Build.VERSION_CODES.S)
        private static void requestSdrToneMapping(MediaFormat mediaFormat) {
            mediaFormat.setInteger(MediaFormat.KEY_COLOR_TRANSFER_REQUEST, MediaFormat.COLOR_TRANSFER_SDR_VIDEO);
        }
    }

    static boolean isUnspecifiedEightBitSdr(ColorInfo colorInfo) {
        return colorInfo != null
                && colorInfo.colorSpace == Format.NO_VALUE
                && colorInfo.colorRange == Format.NO_VALUE
                && colorInfo.colorTransfer == Format.NO_VALUE
                && colorInfo.lumaBitdepth == 8
                && colorInfo.chromaBitdepth == 8
                && ColorInfo.isEquivalentToAssumedSdrDefault(colorInfo);
    }

    static boolean shouldRequestSdrToneMapping(ColorInfo colorInfo) {
        return colorInfo != null
                && (ColorInfo.isTransferHdr(colorInfo)
                || colorInfo.lumaBitdepth > 8
                || colorInfo.chromaBitdepth > 8);
    }
}
