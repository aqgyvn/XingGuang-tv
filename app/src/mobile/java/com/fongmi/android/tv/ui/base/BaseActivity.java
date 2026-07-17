package com.fongmi.android.tv.ui.base;

import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.view.DisplayCutout;
import android.view.View;
import android.view.ViewGroup;
import android.window.OnBackInvokedCallback;
import android.window.OnBackInvokedDispatcher;

import androidx.activity.EdgeToEdge;
import androidx.activity.OnBackPressedCallback;
import androidx.activity.SystemBarStyle;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.FragmentActivity;
import androidx.viewbinding.ViewBinding;

import com.fongmi.android.tv.R;
import com.fongmi.android.tv.utils.ResUtil;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

public abstract class BaseActivity extends AppCompatActivity {

    private OnBackInvokedCallback callback;

    protected abstract ViewBinding getBinding();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        enableEdgeToEdge();
        setContentView(getBinding().getRoot());
        EventBus.getDefault().register(this);
        initView(savedInstanceState);
        setBackCallback();
        initEvent();
    }

    protected FragmentActivity getActivity() {
        return this;
    }

    protected boolean customWall() {
        return false;
    }

    protected boolean lightSystemBars() {
        return true;
    }

    protected void initView(Bundle savedInstanceState) {
    }

    protected void initEvent() {
    }

    protected boolean isVisible(View view) {
        return view.getVisibility() == View.VISIBLE;
    }

    protected boolean isGone(View view) {
        return view.getVisibility() == View.GONE;
    }

    protected void setPadding(ViewGroup layout) {
        setPadding(layout, false);
    }

    protected void setPadding(ViewGroup layout, boolean leftOnly) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return;
        DisplayCutout cutout = ResUtil.getDisplay(this).getCutout();
        if (cutout == null) return;
        int top = cutout.getSafeInsetTop();
        int left = cutout.getSafeInsetLeft();
        int right = cutout.getSafeInsetRight();
        int bottom = cutout.getSafeInsetBottom();
        int padding = left | right | top | bottom;
        layout.setPadding(padding, 0, leftOnly ? 0 : padding, 0);
    }

    protected void noPadding(ViewGroup layout) {
        layout.setPadding(0, 0, 0, 0);
    }

    private void setBackCallback() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT, callback = this::onBackInvoked);
        } else {
            getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
                @Override
                public void handleOnBackPressed() {
                    onBackInvoked();
                }
            });
        }
    }

    private void enableEdgeToEdge() {
        boolean light = lightSystemBars();
        int barColor = ResUtil.getColor(light ? R.color.xg_surface : R.color.black);
        SystemBarStyle style = light ? SystemBarStyle.light(barColor, barColor) : SystemBarStyle.dark(barColor);
        EdgeToEdge.enable(this, style, style);
        getWindow().setStatusBarColor(barColor);
        getWindow().setNavigationBarColor(barColor);
        getWindow().setNavigationBarDividerColor(barColor);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            getWindow().setStatusBarContrastEnforced(false);
            getWindow().setNavigationBarContrastEnforced(false);
        }
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onSubscribe(Object o) {
    }

    protected void onBackInvoked() {
        finish();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        EventBus.getDefault().unregister(this);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) getOnBackInvokedDispatcher().unregisterOnBackInvokedCallback(callback);
    }
}
