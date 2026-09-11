package com.fongmi.android.tv.ui.custom;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.util.AttributeSet;
import android.view.View;
import android.view.animation.LinearInterpolator;

import androidx.core.graphics.ColorUtils;

import com.fongmi.android.tv.R;

public final class EmptyStateView extends View {

    private static final float ART_WIDTH = 160f;
    private static final float ART_HEIGHT = 180f;

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path path = new Path();
    private final int frontColor;
    private final int sideColor;
    private final int flapColor;
    private final int rearColor;
    private final int insideColor;
    private ValueAnimator animator;
    private boolean visible;
    private float phase;

    public EmptyStateView(Context context) {
        this(context, null);
    }

    public EmptyStateView(Context context, AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public EmptyStateView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        int gold = context.getColor(R.color.xg_nav_active);
        frontColor = ColorUtils.blendARGB(gold, Color.WHITE, 0.18f);
        sideColor = gold;
        flapColor = ColorUtils.blendARGB(gold, Color.WHITE, 0.32f);
        rearColor = ColorUtils.blendARGB(gold, Color.BLACK, 0.12f);
        insideColor = ColorUtils.blendARGB(gold, Color.BLACK, 0.68f);
        setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);
        setFocusable(false);
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        float density = getResources().getDisplayMetrics().density;
        int width = Math.max(getSuggestedMinimumWidth(), Math.round(ART_WIDTH * density) + getPaddingLeft() + getPaddingRight());
        int height = Math.max(getSuggestedMinimumHeight(), Math.round(ART_HEIGHT * density) + getPaddingTop() + getPaddingBottom());
        setMeasuredDimension(resolveSize(width, widthMeasureSpec), resolveSize(height, heightMeasureSpec));
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        updateAnimation();
    }

    @Override
    public void onVisibilityAggregated(boolean isVisible) {
        super.onVisibilityAggregated(isVisible);
        visible = isVisible;
        updateAnimation();
    }

    @Override
    protected void onWindowVisibilityChanged(int visibility) {
        super.onWindowVisibilityChanged(visibility);
        updateAnimation();
    }

    @Override
    protected void onSizeChanged(int width, int height, int oldWidth, int oldHeight) {
        super.onSizeChanged(width, height, oldWidth, oldHeight);
        updateAnimation();
    }

    @Override
    protected void onDetachedFromWindow() {
        stopAnimation();
        super.onDetachedFromWindow();
    }

    private void updateAnimation() {
        if (!isAttachedToWindow() || !visible || getWindowVisibility() != VISIBLE
                || getWidth() == 0 || getHeight() == 0 || !ValueAnimator.areAnimatorsEnabled()) {
            stopAnimation();
            return;
        }
        if (animator == null) {
            animator = ValueAnimator.ofFloat(0f, 1f);
            animator.setDuration(2400);
            animator.setRepeatCount(ValueAnimator.INFINITE);
            animator.setInterpolator(new LinearInterpolator());
            animator.addUpdateListener(value -> {
                phase = (float) value.getAnimatedValue();
                invalidate();
            });
        }
        if (!animator.isStarted()) animator.start();
    }

    private void stopAnimation() {
        if (animator != null && animator.isStarted()) animator.cancel();
        if (phase != 0f) {
            phase = 0f;
            invalidate();
        }
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        float width = getWidth() - getPaddingLeft() - getPaddingRight();
        float height = getHeight() - getPaddingTop() - getPaddingBottom();
        float scale = Math.min(width / ART_WIDTH, height / ART_HEIGHT);
        if (scale <= 0) return;

        int save = canvas.save();
        canvas.translate(getPaddingLeft() + (width - ART_WIDTH * scale) / 2f,
                getPaddingTop() + (height - ART_HEIGHT * scale) / 2f);
        canvas.scale(scale, scale);

        float wave = (1f - (float) Math.cos(phase * Math.PI * 2)) / 2f;
        paint.setColor(0x40000000);
        canvas.drawOval(43f + wave * 3f, 150f, 117f - wave * 3f, 158f, paint);
        canvas.translate(0, -6f * wave);

        // The rear flaps, hollow opening, faces and front flaps share fixed hinges.
        float flap = 4f * wave;
        quad(canvas, rearColor, 38, 80, 80, 55, 67, 34 + flap, 25, 59 + flap);
        quad(canvas, flapColor, 80, 55, 122, 80, 135, 59 + flap, 93, 34 + flap);
        quad(canvas, insideColor, 38, 80, 80, 55, 122, 80, 80, 104);
        quad(canvas, rearColor, 80, 55, 122, 80, 101, 92, 80, 80);
        quad(canvas, frontColor, 38, 80, 80, 104, 80, 145, 38, 121);
        quad(canvas, sideColor, 80, 104, 122, 80, 122, 121, 80, 145);
        quad(canvas, flapColor, 38, 80, 80, 104, 62, 122 - flap, 20, 98 - flap);
        quad(canvas, frontColor, 80, 104, 122, 80, 140, 98 - flap, 98, 122 - flap);
        quad(canvas, 0xfffff6df, 51, 116, 64, 123, 64, 132, 51, 125);
        canvas.restoreToCount(save);
    }

    private void quad(Canvas canvas, int color, float x1, float y1, float x2, float y2,
                      float x3, float y3, float x4, float y4) {
        path.rewind();
        path.moveTo(x1, y1);
        path.lineTo(x2, y2);
        path.lineTo(x3, y3);
        path.lineTo(x4, y4);
        path.close();
        paint.setColor(color);
        canvas.drawPath(path, paint);
    }
}
