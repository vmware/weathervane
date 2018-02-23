/*
Copyright (c) 2017 VMware, Inc. All Rights Reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
package com.vmware.weathervane.auction.data.imageStore;

import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URISyntaxException;
import java.util.List;

import javax.imageio.ImageIO;

import org.apache.commons.io.IOUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.model.ImageStoreBenchmarkInfo;

/**
 * This is an implementation of the ImageStoreFacade that stores all images
 * in a single directory on the filesystem..
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
				
		logger.info("Resizing and then dropping image for " + imageInfo.getEntitytype() + 
				" with id=" + imageInfo.getEntityid());

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
		logger.info("addImage with all bytes. Writing image for " + imageInfo.getEntitytype() + " with id=" + imageInfo.getEntityid());

		/*
		 *  First save the imageInfo.  This will cause the image to 
		 *  get a unique id which will be used as the handle
		 */
		imageInfo.setFormat(getImageFormat());
		imageInfo = imageInfoRepository.save(imageInfo);
		
		return imageInfo;
	}
	
	@Override
	public byte[] retrieveImage(String imageHandle, ImageSize size) throws NoSuchImageException, IOException {
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
