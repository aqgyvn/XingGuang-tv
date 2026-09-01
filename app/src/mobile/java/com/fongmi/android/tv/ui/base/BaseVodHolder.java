package com.fongmi.android.tv.ui.base;

import android.view.View;
import android.widget.ImageView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.bumptech.glide.Glide;
import com.fongmi.android.tv.bean.Vod;

public abstract class BaseVodHolder extends RecyclerView.ViewHolder {

    public BaseVodHolder(@NonNull View itemView) {
        super(itemView);
    }

    public abstract void initView(Vod item);

    protected abstract ImageView getImageView();

    public final void unbind() {
        ImageView image = getImageView();
        Glide.with(image).clear(image);
        image.setImageDrawable(null);
    }
}
