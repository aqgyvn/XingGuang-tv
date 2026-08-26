package com.fongmi.android.tv.ui.dialog;

import android.app.Activity;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.coordinatorlayout.widget.CoordinatorLayout;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.viewbinding.ViewBinding;

import com.fongmi.android.tv.R;
import com.fongmi.android.tv.utils.ResUtil;
import com.fongmi.android.tv.utils.Util;
import com.google.android.material.bottomsheet.BottomSheetBehavior;
import com.google.android.material.bottomsheet.BottomSheetDialog;
import com.google.android.material.bottomsheet.BottomSheetDialogFragment;

public abstract class BaseDialog extends BottomSheetDialogFragment {

    protected abstract ViewBinding getBinding(@NonNull LayoutInflater inflater, @Nullable ViewGroup container);

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        return getBinding(inflater, container).getRoot();
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        initView();
        initEvent();
    }

    protected void initView() {
    }

    protected void initEvent() {
    }

    protected boolean transparent() {
        return false;
    }

    protected int sheetWidth() {
        return ViewGroup.LayoutParams.MATCH_PARENT;
    }

    protected void setDimAmount(float amount) {
        if (getDialog() != null && getDialog().getWindow() != null) {
            getDialog().getWindow().setDimAmount(amount);
            getDialog().getWindow().addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);
        }
    }

    @NonNull
    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        BottomSheetDialog dialog = (BottomSheetDialog) super.onCreateDialog(savedInstanceState);
        dialog.setOnShowListener((DialogInterface f) -> setBehavior(dialog));
        setWindow(dialog);
        return dialog;
    }

    private void setBehavior(BottomSheetDialog dialog) {
        FrameLayout bottomSheet = dialog.findViewById(com.google.android.material.R.id.design_bottom_sheet);
        applySheetWidth(bottomSheet);
        if (transparent()) bottomSheet.setBackgroundColor(ResUtil.getColor(R.color.transparent));
        BottomSheetBehavior<FrameLayout> behavior = BottomSheetBehavior.from(bottomSheet);
        behavior.setState(BottomSheetBehavior.STATE_EXPANDED);
        behavior.setSkipCollapsed(true);
    }

    private void applySheetWidth(FrameLayout bottomSheet) {
        ViewGroup.LayoutParams params = bottomSheet.getLayoutParams();
        if (params instanceof CoordinatorLayout.LayoutParams) {
            CoordinatorLayout.LayoutParams layoutParams = (CoordinatorLayout.LayoutParams) params;
            layoutParams.width = sheetWidth();
            layoutParams.gravity = Gravity.CENTER_HORIZONTAL | Gravity.TOP;
        } else {
            params.width = sheetWidth();
        }
        bottomSheet.setLayoutParams(params);
    }

    private void setWindow(Dialog dialog) {
        Activity activity = getActivity();
        if (activity == null || dialog == null) return;
        Window dialogWindow = dialog.getWindow();
        Window activityWindow = activity.getWindow();
        if (activityWindow == null || dialogWindow == null) return;
        int activityFlags = activityWindow.getAttributes().flags;
        dialogWindow.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        boolean isFullscreen = (activityFlags & WindowManager.LayoutParams.FLAG_FULLSCREEN) == WindowManager.LayoutParams.FLAG_FULLSCREEN;
        if (isFullscreen) Util.applyFullscreenWindow(activity, dialogWindow);
    }

    @Override
    public void onStart() {
        super.onStart();
        Activity activity = getActivity();
        Dialog dialog = getDialog();
        if (dialog == null) return;
        FrameLayout bottomSheet = dialog.findViewById(com.google.android.material.R.id.design_bottom_sheet);
        if (bottomSheet != null) applySheetWidth(bottomSheet);
        Util.applyFullscreenWindow(activity, dialog.getWindow());
        if (isFullscreen(activity)) {
            dialog.getWindow().setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
            applyFullscreenInsets(dialog);
        }
    }

    private boolean isFullscreen(Activity activity) {
        return activity != null && activity.getWindow() != null && (activity.getWindow().getAttributes().flags & WindowManager.LayoutParams.FLAG_FULLSCREEN) != 0;
    }

    private void applyFullscreenInsets(Dialog dialog) {
        FrameLayout bottomSheet = dialog.findViewById(com.google.android.material.R.id.design_bottom_sheet);
        View container = dialog.findViewById(com.google.android.material.R.id.container);
        View coordinator = dialog.findViewById(com.google.android.material.R.id.coordinator);
        if (bottomSheet != null) {
            bottomSheet.setFitsSystemWindows(false);
            bottomSheet.setPadding(0, 0, 0, 0);
        }
        if (container != null) {
            container.setFitsSystemWindows(false);
            container.setPadding(0, 0, 0, 0);
        }
        if (coordinator != null) {
            coordinator.setFitsSystemWindows(false);
            coordinator.setPadding(0, 0, 0, 0);
        }
        clearSystemBarInsets(bottomSheet);
        clearSystemBarInsets(container);
        clearSystemBarInsets(coordinator);
    }

    private void clearSystemBarInsets(View view) {
        if (view == null) return;
        ViewCompat.setOnApplyWindowInsetsListener(view, (target, insets) -> new WindowInsetsCompat.Builder(insets)
                .setInsets(WindowInsetsCompat.Type.systemBars(), Insets.NONE)
                .setInsets(WindowInsetsCompat.Type.displayCutout(), Insets.NONE)
                .build());
        ViewCompat.requestApplyInsets(view);
    }
}
