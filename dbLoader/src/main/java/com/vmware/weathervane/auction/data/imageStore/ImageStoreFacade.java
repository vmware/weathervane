/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.imageStore;

import java.awt.image.BufferedImage;
import java.io.IOException;
import java.util.List;
import java.util.UUID;

import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.model.ImageStoreBenchmarkInfo;

public interface ImageStoreFacade {
	
	public enum ImageSize {THUMBNAIL, PREVIEW, FULL};
	
	/**
	 * This method is used to add an image to the image store. It creates the preview
	 * and thumbnail versions of the images.
	 * 
	 * @param imageInfo
	 * @param imageData The image as an array of bytes as received in MIME message
	 * @return A handle that can be used to retrieve the image
	 * @throws IOException
	 * @throws ImageQueueFullException 
	 */
	public ImageInfo addImage(ImageInfo imageInfo, byte[] imageData) throws IOException, ImageQueueFullException;

	public ImageInfo addImage(ImageInfo imageInfo, BufferedImage fullImageBytes, 
			BufferedImage previewImageBytes, BufferedImage thumbnailImageBytes) throws IOException;


	/*
	 * Bulk adds imageInfos and images to ImageStore 
	 */
	void addImages(List<ImageInfo> imageInfos, List<BufferedImage> fullImage,
			List<BufferedImage> previewImage, List<BufferedImage> thumbnailImage) throws IOException;

	/**
	 * This method is used to retrieve a previously stored image using the 
	 * imageHandle. If the requested size doesn't exist, returns the
	 * next smaller size that does exist, or throws a NoSuchImageException
	 * 
	 * @param imageHandle The handle that identifies the image
	 * @param size The size of the image to return.
	 * @throws NoSuchImageException If no such image exists in the image store
	 * @throws IOException 
	 */
	public byte[] retrieveImage(UUID imageHandle, ImageSize size) throws NoSuchImageException, IOException;

	/**
	 * Used by the benchmark infrastructure to clear out user-added images 
	 * between runs.
	 * 
	 */
	public void clearNonpreloadedImages();
	
	public List<ImageInfo> getImageInfos(String entityType, Long entityId);

	/**
	 * This method empties the image store.
	 * @throws IOException 
	 */
	public void resetImageStore() throws IOException;

	/**
	 * Returns the image scaled to the given size.
	 * 
	 * @param sourceImage
	 * @param size
	 * @return
	 */
	BufferedImage scaleImageToSize(BufferedImage sourceImage, ImageSize size);
	
	/*
	 * Set the format in which images should be saved in the image store
	 */
	public void setImageFormat(String format);
	public String getImageFormat();
	
	/*
	 * Set the size for thumbnail images
	 */
	public void setThumbnailWidth(int width);
	public void setThumbnailHeight(int height);

	/*
	 * Set the size for preview images
	 */
	public void setPreviewWidth(int width);
	public void setPreviewHeight(int height);
	
	/*
	 * Methods for recording and retrieving the benchmark scale
	 */
	void setBenchmarkInfo(ImageStoreBenchmarkInfo benchmarkInfo);
	ImageStoreBenchmarkInfo getBenchmarkInfo() throws NoBenchmarkInfoException, NoBenchmarkInfoNeededException;

	void stopServiceThreads();

	List<Thread> getImageWriterThreads();


}
