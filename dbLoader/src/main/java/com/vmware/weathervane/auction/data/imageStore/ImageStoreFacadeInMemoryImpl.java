/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.imageStore;

import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URISyntaxException;
import java.util.List;
import java.util.UUID;

import javax.imageio.ImageIO;

import org.apache.commons.io.IOUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.model.ImageStoreBenchmarkInfo;

/**
 * This is an implementation of the ImageStoreFacade that stores all images in memory
 * 
 * @author Hal
 *
 */
public class ImageStoreFacadeInMemoryImpl extends ImageStoreFacadeBaseImpl {

	private static final Logger logger = LoggerFactory.getLogger(ImageStoreFacadeInMemoryImpl.class);

	// These are the images that are stored in memory
	private byte[] fullSizeImage;
	private byte[] previewSizeImage;
	private byte[] thumbnailSizeImage;
	
	public ImageStoreFacadeInMemoryImpl() throws URISyntaxException, IOException {
		/*
		 * Read the images and save them
		 */
		InputStream inStream = ImageStoreFacadeInMemoryImpl.class.getClassLoader().getResourceAsStream("FULL.jpg");
		fullSizeImage = IOUtils.toByteArray(inStream);
		inStream.close();
		
		inStream = ImageStoreFacadeInMemoryImpl.class.getClassLoader().getResourceAsStream("PREVIEW.jpg");
		previewSizeImage = IOUtils.toByteArray(inStream);
		inStream.close();

		inStream = ImageStoreFacadeInMemoryImpl.class.getClassLoader().getResourceAsStream("THUMBNAIL.jpg");
		thumbnailSizeImage = IOUtils.toByteArray(inStream);
		inStream.close();

		this.setImageFormat("jpg");
	}
	
	private void resizeImage(BufferedImage sourceImage, ImageStoreFacade.ImageSize size) throws IOException {

		// Don't bother resizing for a full-size image
		BufferedImage finalImage = sourceImage;
		if (size != ImageSize.FULL) {
			finalImage = scaleImageToSize(sourceImage, size);
		}

		/*
		 * Since this impl always returns the same file, we don't actually store the file
		 */
	}
	
	@Override
	protected void saveImage(ImageInfo imageInfo, byte[] imageBytes) throws IOException {

		/*
		 *  First save the imageInfo.  This will cause the image to 
		 *  get a unique id which will be used as the handle
		 */
		imageInfo.setFormat(getImageFormat());
		imageInfo = imageInfoRepository.save(imageInfo);
	}		

	@Override
	protected void resizeAndSaveImage(ImageInfo imageInfo, byte[] imageBytes) throws IOException {

			/*
			 *  First save the imageInfo.  This will cause the image to 
			 *  get a unique id which will be used as the handle
			 */
			imageInfo.setFormat(getImageFormat());
			imageInfo = imageInfoRepository.save(imageInfo);

		BufferedImage image = ImageIO.read(new ByteArrayInputStream(imageBytes));
				
		logger.info("Resizing and then dropping image with id=" + imageInfo.getKey().getEntityid());

		// Resize but don't store image
		for (ImageSize size : ImageStoreFacade.ImageSize.values()) {
			resizeImage(image, size);
		}
		
	}
	
	@Override
	public void addImages(List<ImageInfo> imageInfos, List<BufferedImage> fullImages,
			List<BufferedImage> previewImages, List<BufferedImage> thumbnailImages) throws IOException {
		/*
		 * Prepare the images for insert. need to save the ImageInfos
		 * individually to cause the images to get unique ids
		 */
		for (ImageInfo anImageInfo : imageInfos) {
			this.addImage(anImageInfo, null, null, null);
		}

	}

	@Override
	public ImageInfo addImage(ImageInfo imageInfo, BufferedImage fullImage, 
			BufferedImage previewImage, BufferedImage thumbnailImage) throws IOException {
		logger.info("addImage with all bytes. Writing image with id=" + imageInfo.getKey().getEntityid());

		/*
		 *  First save the imageInfo.  This will cause the image to 
		 *  get a unique id which will be used as the handle
		 */
		imageInfo.setFormat(getImageFormat());
		imageInfo = imageInfoRepository.save(imageInfo);
		
		return imageInfo;
	}
	
	@Override
	public byte[] retrieveImage(UUID imageHandle, ImageSize size) throws NoSuchImageException, IOException {
		// Get the imageInfo for the image

		byte[] image;
		switch (size) {
		case FULL:
			image = fullSizeImage;
			break;

		case PREVIEW:
			image = previewSizeImage;
			break;

		default:
			image = thumbnailSizeImage;
			break;
						
		}
				
 		return image;
	}

	@Override
	public void resetImageStore() throws IOException {
	}

	@Override
	public void setBenchmarkInfo(ImageStoreBenchmarkInfo imageStoreBenchmarkInfo) {
	}

	@Override
	public ImageStoreBenchmarkInfo getBenchmarkInfo() throws NoBenchmarkInfoNeededException  {
		throw new NoBenchmarkInfoNeededException();
	}
	
}
