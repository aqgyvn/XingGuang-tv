package com.fongmi.android.tv.ui.dialog;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentActivity;
import androidx.viewbinding.ViewBinding;

import com.fongmi.android.tv.R;
import com.fongmi.android.tv.Setting;
import com.fongmi.android.tv.databinding.DialogPlayerEngineBinding;
import com.google.android.material.bottomsheet.BottomSheetDialogFragment;

public final class PlayerEngineDialog extends BaseDialog {

    private DialogPlayerEngineBinding binding;
    private Runnable callback;
    private TextView target;

    public static void setText(TextView view) {
        if (view == null) return;
        switch (Setting.getPlayer()) {
            case Setting.PLAYER_IJK:
                view.setText(R.string.play_ijk);
                break;
            case Setting.PLAYER_MPV:
                view.setText(R.string.play_mpv);
                break;
            default:
                view.setText(R.string.play_exo);
                break;
        }
    }

    public static void show(FragmentActivity activity, TextView target, Runnable callback) {
        for (Fragment f : activity.getSupportFragmentManager().getFragments()) if (f instanceof BottomSheetDialogFragment) return;
        PlayerEngineDialog dialog = new PlayerEngineDialog();
        dialog.target = target;
        dialog.callback = callback;
        dialog.show(activity.getSupportFragmentManager(), null);
    }

    @Override
    protected ViewBinding getBinding(@NonNull LayoutInflater inflater, @Nullable ViewGroup container) {
        return binding = DialogPlayerEngineBinding.inflate(inflater, container, false);
    }

    @Override
    protected void initView() {
        int player = Setting.getPlayer();
        binding.exo.setSelected(player == Setting.PLAYER_EXO);
        binding.ijk.setSelected(player == Setting.PLAYER_IJK);
        binding.mpv.setSelected(player == Setting.PLAYER_MPV);
    }

    @Override
    protected void initEvent() {
        binding.exo.setOnClickListener(view -> select(Setting.PLAYER_EXO));
        binding.ijk.setOnClickListener(view -> select(Setting.PLAYER_IJK));
        binding.mpv.setOnClickListener(view -> select(Setting.PLAYER_MPV));
    }

    private void select(int player) {
        boolean changed = Setting.getPlayer() != player;
        Setting.putPlayer(player);
        setText(target);
        dismiss();
        if (changed && callback != null) callback.run();
    }
}
