package com.fongmi.android.tv.ui.dialog;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;

import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.fragment.app.FragmentActivity;

import com.fongmi.android.tv.bean.Episode;
import com.fongmi.android.tv.databinding.DialogEpisodeListBinding;
import com.fongmi.android.tv.ui.adapter.EpisodeAdapter;
import com.fongmi.android.tv.ui.base.ViewType;
import com.fongmi.android.tv.utils.ResUtil;
import com.fongmi.android.tv.utils.Util;
import com.google.android.material.sidesheet.SideSheetDialog;

import java.util.List;

public class EpisodeListDialog implements EpisodeAdapter.OnClickListener {

    private final EpisodeAdapter.OnClickListener listener;
    private final FragmentActivity activity;
    private DialogEpisodeListBinding binding;
    private SideSheetDialog dialog;
    private EpisodeAdapter adapter;
    private List<Episode> episodes;

    public static EpisodeListDialog create(FragmentActivity activity) {
        return new EpisodeListDialog(activity);
    }

    public EpisodeListDialog(FragmentActivity activity) {
        this.listener = (EpisodeAdapter.OnClickListener) activity;
        this.activity = activity;
    }

    public EpisodeListDialog episodes(List<Episode> episodes) {
        this.episodes = episodes;
        return this;
    }

    public void show() {
        initDialog();
        initView();
    }

    private void initDialog() {
        binding = DialogEpisodeListBinding.inflate(LayoutInflater.from(activity));
        dialog = new SideSheetDialog(activity);
        dialog.setContentView(binding.getRoot());
        dialog.getBehavior().setDraggable(false);
        Window window = dialog.getWindow();
        if (window != null) {
            window.setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);
            window.addFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS);
            window.setDimAmount(0);
        }
        Util.applyFullscreenWindow(activity, window);
        applyFullscreenLayout(window);
        dialog.show();
        applyFullscreenLayout(window);
    }

    private void applyFullscreenLayout(Window window) {
        if (window != null) {
            WindowCompat.setDecorFitsSystemWindows(window, false);
            View decor = window.getDecorView();
            decor.setSystemUiVisibility(decor.getSystemUiVisibility()
                    | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    | View.SYSTEM_UI_FLAG_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
            ViewCompat.setOnApplyWindowInsetsListener(decor, (target, insets) -> WindowInsetsCompat.CONSUMED);
            ViewCompat.requestApplyInsets(decor);
        }
        if (window != null) window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
        View content = dialog.findViewById(android.R.id.content);
        View container = dialog.findViewById(com.google.android.material.R.id.container);
        View coordinator = dialog.findViewById(com.google.android.material.R.id.coordinator);
        FrameLayout sheet = dialog.findViewById(com.google.android.material.R.id.m3_side_sheet);
        clearSystemBarInsets(content);
        clearSystemBarInsets(container);
        clearSystemBarInsets(coordinator);
        clearSystemBarInsets(sheet);
        if (sheet != null) {
            sheet.addOnLayoutChangeListener((view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) -> applySheetBounds((FrameLayout) view));
        }
        applySheetBounds(sheet);
        if (sheet != null) sheet.post(() -> applySheetBounds(sheet));
    }

    private void clearSystemBarInsets(View view) {
        if (view == null) return;
        view.setFitsSystemWindows(false);
        view.setPadding(0, 0, 0, 0);
        ViewCompat.setOnApplyWindowInsetsListener(view, (target, insets) -> {
            target.setFitsSystemWindows(false);
            target.setPadding(0, 0, 0, 0);
            return WindowInsetsCompat.CONSUMED;
        });
        ViewCompat.requestApplyInsets(view);
    }

    private void applySheetBounds(FrameLayout sheet) {
        if (sheet == null) return;
        int minWidth = ResUtil.dp2px(200);
        int maxWidth = ResUtil.getScreenWidth() / 3;
        for (Episode item : episodes) minWidth = Math.max(minWidth, ResUtil.getTextWidth(item.getName(), 14));
        ViewGroup.LayoutParams params = sheet.getLayoutParams();
        int width = Math.min(minWidth, maxWidth);
        boolean changed = params.width != width || params.height != ViewGroup.LayoutParams.MATCH_PARENT;
        params.width = width;
        params.height = ViewGroup.LayoutParams.MATCH_PARENT;
        if (params instanceof ViewGroup.MarginLayoutParams) {
            ViewGroup.MarginLayoutParams margins = (ViewGroup.MarginLayoutParams) params;
            changed |= margins.topMargin != 0 || margins.bottomMargin != 0;
            margins.topMargin = 0;
            margins.bottomMargin = 0;
        }
        if (changed) sheet.setLayoutParams(params);
    }

    private void initView() {
        setRecyclerView();
        setEpisode();
    }

    private void setRecyclerView() {
        binding.recycler.setHasFixedSize(true);
        binding.recycler.setItemAnimator(null);
        binding.recycler.setAdapter(adapter = new EpisodeAdapter(this, ViewType.GRID));
    }

    private void setEpisode() {
        adapter.addAll(episodes);
        binding.recycler.scrollToPosition(adapter.getPosition());
    }

    @Override
    public void onItemClick(Episode item) {
        listener.onItemClick(item);
        dialog.dismiss();
    }
}
