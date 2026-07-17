package com.android.cast.dlna.dmr;

import android.os.Parcel;
import android.os.Parcelable;

import androidx.annotation.NonNull;

public class CastAction implements Parcelable {

    public static final Creator<CastAction> CREATOR = new Creator<>() {
        @Override
        public CastAction createFromParcel(Parcel in) {
            return new CastAction(in);
        }

        @Override
        public CastAction[] newArray(int size) {
            return new CastAction[size];
        }
    };

    private final String currentURI;
    private final String currentURIMetaData;

    public CastAction() {
        this("", "");
    }

    public CastAction(String currentURI, String currentURIMetaData) {
        this.currentURI = currentURI;
        this.currentURIMetaData = currentURIMetaData;
    }

    protected CastAction(Parcel in) {
        currentURI = in.readString();
        currentURIMetaData = in.readString();
    }

    public String getCurrentURI() {
        return currentURI == null ? "" : currentURI;
    }

    public String getCurrentURIMetaData() {
        return currentURIMetaData == null ? "" : currentURIMetaData;
    }

    @Override
    public int describeContents() {
        return 0;
    }

    @Override
    public void writeToParcel(@NonNull Parcel dest, int flags) {
        dest.writeString(currentURI);
        dest.writeString(currentURIMetaData);
    }
}
