package com.fongmi.android.tv.ui.adapter;

import android.view.LayoutInflater;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.bumptech.glide.Glide;
import com.fongmi.android.tv.bean.Vod;
import com.fongmi.android.tv.databinding.AdapterHomeVodBinding;
import com.fongmi.android.tv.utils.ImgUtil;

public class HomeVodAdapter extends BaseDiffAdapter<Vod, HomeVodAdapter.ViewHolder> {

    private final OnClickListener listener;

    public HomeVodAdapter(OnClickListener listener) {
        this.listener = listener;
    }

    public interface OnClickListener {

        void onItemClick(Vod item);

        boolean onLongClick(Vod item);
    }

    @Override
    public void onBindViewHolder(@NonNull ViewHolder holder, int position) {
        holder.bind(getItem(position));
    }

    @Override
    public void onViewRecycled(@NonNull ViewHolder holder) {
        holder.unbind();
    }

    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        return new ViewHolder(AdapterHomeVodBinding.inflate(LayoutInflater.from(parent.getContext()), parent, false), listener);
    }

    static class ViewHolder extends RecyclerView.ViewHolder {

        private final AdapterHomeVodBinding binding;
        private final OnClickListener listener;

        ViewHolder(AdapterHomeVodBinding binding, OnClickListener listener) {
            super(binding.getRoot());
            this.binding = binding;
            this.listener = listener;
        }

        void bind(Vod item) {
            binding.name.setText(item.getName());
            binding.name.setSelected(true);
            binding.remark.setText(item.getRemarks());
            binding.remark.setVisibility(item.getRemarkVisible());
            binding.getRoot().setOnClickListener(v -> listener.onItemClick(item));
            binding.getRoot().setOnLongClickListener(v -> listener.onLongClick(item));
            ImgUtil.load(item.getName(), item.getPic(), binding.image);
        }

        void unbind() {
            Glide.with(binding.image).clear(binding.image);
        }
    }
}
