/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.dbloader;

import java.awt.image.BufferedImage;

public class ImagesHolder {
	
	private BufferedImage fullSize;
	private BufferedImage previewSize;
	private BufferedImage thumbnailSize;
		
	public BufferedImage getFullSize() {
		return fullSize;
	}
	public void setFullSize(BufferedImage fullSize) {
		this.fullSize = fullSize;
	}
	public BufferedImage getPreviewSize() {
		return previewSize;
	}
	public void setPreviewSize(BufferedImage previewSize) {
		this.previewSize = previewSize;
	}
	public BufferedImage getThumbnailSize() {
		return thumbnailSize;
	}
	public void setThumbnailSize(BufferedImage thumbnailSize) {
		this.thumbnailSize = thumbnailSize;
	}
	
}
