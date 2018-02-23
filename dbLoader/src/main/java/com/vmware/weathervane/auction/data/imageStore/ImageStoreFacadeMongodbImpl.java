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
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import javax.imageio.ImageIO;
import javax.inject.Inject;
import javax.inject.Named;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.mongodb.core.MongoOperations;

import com.vmware.weathervane.auction.data.imageStore.model.ImageFull;
import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.imageStore.model.ImagePreview;
import com.vmware.weathervane.auction.data.imageStore.model.ImageThumbnail;
import com.vmware.weathervane.auction.data.model.ImageStoreBenchmarkInfo;
import com.vmware.weathervane.auction.data.repository.ImageFullRepository;
import com.vmware.weathervane.auction.data.repository.ImagePreviewRepository;
import com.vmware.weathervane.auction.data.repository.ImageStoreBenchmarkInfoRepository;
import com.vmware.weathervane.auction.data.repository.ImageThumbnailRepository;

/**
 * This is an implementation of the ImageStoreFacade that stores all images in a
 * collection in MongoDB.
 * 
 * @author Hal
 * 
 */
public class ImageStoreFacadeMongodbImpl extends ImageStoreFacadeBaseImpl {

	private static final Logger logger = LoggerFactory.getLogger(ImageStoreFacadeMongodbImpl.class);

	@Inject
	ImageFullRepository imageFullRepository;

	@Inject
	ImagePreviewRepository imagePreviewRepository;

	@Inject
	ImageThumbnailRepository imageThumbnailRepository;

	@Inject
	ImageStoreBenchmarkInfoRepository imageStoreBenchmarkInfoRepository;

	@Inject
	@Named("imageInfoMongoTemplate")
	MongoOperations imageInfoMongoTemplate;

	@Inject
	@Named("fullImageMongoTemplate")
	MongoOperations fullImageMongoTemplate;

	@Inject
	@Named("previewImageMongoTemplate")
	MongoOperations previewImageMongoTemplate;

	@Inject
	@Named("thumbnailImageMongoTemplate")
	MongoOperations thumbnailImageMongoTemplate;

	/*
	 * Method to print stats for cache misses at end of runs
	 */
//	@PreDestroy
//	private void printImageCacheStats() {
//		double imageInfoMissRate = imageInfoMisses / (double) imageInfoGets;
//		
//		logger.warn("ImageInfo Cache Stats: ");
//		logger.warn("ImageInfos.  Gets = " + imageInfoGets + ", misses = " + imageInfoMisses + ", miss rate = " + imageInfoMissRate);
//	}


	protected byte[] resizeImage(BufferedImage sourceImage, ImageStoreFacade.ImageSize size)
			throws IOException {
		// Don't bother resizing for a full-size image
		BufferedImage finalImage = sourceImage;
		if (size != ImageSize.FULL) {
			finalImage = scaleImageToSize(sourceImage, size);
		}

		ByteArrayOutputStream baos = new ByteArrayOutputStream();

		ImageIO.write(finalImage, "jpg", baos);
		baos.flush();
		byte[] imageBytes = baos.toByteArray();
		baos.close();

		return imageBytes;
	}
	
	@Override
	protected void resizeAndSaveImage(ImageInfo imageInfo, byte[] imageBytes) throws IOException {
		/*
		 * First save the imageInfo. This will cause the image to get a unique
		 * id which will be used as the handle
		 */
		imageInfo.setFormat(getImageFormat());
		imageInfo = imageInfoRepository.save(imageInfo);

		String imageId = imageInfo.getId();

		boolean preloaded = imageInfo.isPreloaded();

		// put the full size image on the queue to be written
		ImageFull imageFull = new ImageFull();
		imageFull.setImage(imageBytes);
		imageFull.setImageid(imageId);
		imageFull.setPreloaded(preloaded);
		imageFullRepository.saveImage(imageFull);

		BufferedImage image = ImageIO.read(new ByteArrayInputStream(imageBytes));

		// put the preview size image on the queue to be written
		ImagePreview imagePreview = new ImagePreview();
		imagePreview.setImage(resizeImage(image, ImageSize.PREVIEW));
		imagePreview.setImageid(imageId);
		imagePreview.setPreloaded(preloaded);
		imagePreviewRepository.saveImage(imagePreview);

		// put the thumbnail size image on the queue to be written
		ImageThumbnail imageThumbnail = new ImageThumbnail();
		imageThumbnail.setImage(resizeImage(image, ImageSize.THUMBNAIL));
		imageThumbnail.setImageid(imageId);
		imageThumbnail.setPreloaded(preloaded);
		imageThumbnailRepository.saveImage(imageThumbnail);
		
	}
	
	@Override
	protected void saveImage(ImageInfo imageInfo, byte[] imageBytes) throws IOException {
		/*
		 * First save the imageInfo. This will cause the image to get a unique
		 * id which will be used as the handle
		 */
		imageInfo.setFormat(getImageFormat());
		imageInfo = imageInfoRepository.save(imageInfo);

		String imageId = imageInfo.getId();

		boolean preloaded = imageInfo.isPreloaded();

		// save the full size image 
		ImageFull imageFull = new ImageFull();
		imageFull.setImage(imageBytes);
		imageFull.setImageid(imageId);
		imageFull.setPreloaded(preloaded);
		imageFullRepository.saveImage(imageFull);
		
	}
	
	@Override
	public ImageInfo addImage(ImageInfo imageInfo, BufferedImage fullImage, BufferedImage previewImage,
			BufferedImage thumbnailImage) throws IOException {
		logger.info("addImage with all bytes. Writing image for " + imageInfo.getEntitytype()
				+ " with id=" + imageInfo.getEntityid());

		/*
		 * First save the imageInfo. This will cause the image to get a unique
		 * id which will be used as the handle
		 */
		imageInfo.setFormat(getImageFormat());
		imageInfo = imageInfoRepository.save(imageInfo);
		String imageId = imageInfo.getId();
		boolean preloaded = imageInfo.isPreloaded();

		// put the full size image on the queue to be written
		if (fullImage != null) {
			logger.debug("addImage bytes adding full image for " + imageInfo.getEntitytype() + ":"
					+ imageInfo.getEntityid());

			// Randomize the image
			ImageFull imageFull = new ImageFull();
			imageFull.setImage(randomizeImage(fullImage));
			imageFull.setImageid(imageId);
			imageFull.setPreloaded(preloaded);
			imageFullRepository.save(imageFull);
		}

		// put the preview size image on the queue to be written
		if (previewImage != null) {
			logger.debug("addImage bytes adding preview image for " + imageInfo.getEntitytype() + ":"
					+ imageInfo.getEntityid());
			
			// Randomize the image
			ImagePreview imagePreview = new ImagePreview();
			imagePreview.setImage(randomizeImage(previewImage));
			imagePreview.setImageid(imageId);
			imagePreview.setPreloaded(preloaded);
			imagePreviewRepository.save(imagePreview);
		}

		// put the thumbnail size image on the queue to be written
		if (thumbnailImage != null) {
			logger.debug("addImage bytes adding thumbnail image for " + imageInfo.getEntitytype() + ":"
					+ imageInfo.getEntityid());
			
			// Randomize the image
			ImageThumbnail imageThumbnail = new ImageThumbnail();
			imageThumbnail.setImage(randomizeImage(thumbnailImage));
			imageThumbnail.setImageid(imageId);
			imageThumbnail.setPreloaded(preloaded);
			imageThumbnailRepository.save(imageThumbnail);
		}
		return imageInfo;
	}

	@Override
	public void addImages(List<ImageInfo> imageInfos, List<BufferedImage> fullImages,
			List<BufferedImage> previewImages, List<BufferedImage> thumbnailImages) throws IOException {
		logger.info("addImages with all bytes.");

		/*
		 * Prepare the images for insert. need to save the ImageInfos
		 * individually to cause the images to get unique ids
		 */
		for (ImageInfo anImageInfo : imageInfos) {

			BufferedImage imageFull = null;
			BufferedImage imagePreview = null;
			BufferedImage imageThumbnail = null;

			// Write out the full size image
			if ((fullImages.size() > 0) && (fullImages.get(0) != null)) {
				imageFull = fullImages.remove(0);
			}

			// Write out the preview size image
			if ((previewImages.size() > 0) && (previewImages.get(0) != null)) {
				imagePreview = previewImages.remove(0);
			}

			// Write out the Thumbnail size image
			if ((thumbnailImages.size() > 0) && (thumbnailImages.get(0) != null)) {
				imageThumbnail = thumbnailImages.remove(0);
			}
			this.addImage(anImageInfo, imageFull, imagePreview, imageThumbnail);
		}

	}

	@Override
	public byte[] retrieveImage(String imageHandle, ImageSize size) throws NoSuchImageException,
			IOException {
		logger.info("retrieveImage imageHandle = " + imageHandle + ", imageSize = " + size);
		switch (size) {
		case THUMBNAIL:
			List<ImageThumbnail> thumbs = imageThumbnailRepository.findByImageid(imageHandle);
			if (thumbs == null) {
				logger.warn("retrieveImage thumbs = null, imageHandle = " + imageHandle
						+ ", imageSize = " + size);
				throw new NoSuchImageException();
			}
			return thumbs.get(0).getImage();

		case PREVIEW:
			List<ImagePreview> previews = imagePreviewRepository.findByImageid(imageHandle);
			if (previews == null) {
				logger.warn("retrieveImage previews = null, imageHandle = " + imageHandle
						+ ", imageSize = " + size);
				throw new NoSuchImageException();
			}
			return previews.get(0).getImage();

		default:
			List<ImageFull> fulls = imageFullRepository.findByImageid(imageHandle);
			if (fulls == null) {
				logger.warn("retrieveImage fulls = null, imageHandle = " + imageHandle
						+ ", imageSize = " + size);
				throw new NoSuchImageException();
			}
			return fulls.get(0).getImage();
		}
	}

	@Override
	public void clearNonpreloadedImages() {
		logger.info("clearNonPreloadedImages");
		imageFullRepository.deleteByPreloaded(false);
		imageInfoRepository.deleteByPreloaded(false);
		imagePreviewRepository.deleteByPreloaded(false);
		imageThumbnailRepository.deleteByPreloaded(false);
	}

	@Override
	public void resetImageStore() throws IOException {
		// empty mongo collections
		fullImageMongoTemplate.dropCollection("imageFull");
		previewImageMongoTemplate.dropCollection("imagePreview");
		thumbnailImageMongoTemplate.dropCollection("imageThumbnail");
		imageInfoMongoTemplate.dropCollection("imageInfo");

	}

	@Override
	public void setBenchmarkInfo(ImageStoreBenchmarkInfo imageStoreBenchmarkInfo) {

		imageStoreBenchmarkInfoRepository.save(imageStoreBenchmarkInfo);
	}

	@Override
	public ImageStoreBenchmarkInfo getBenchmarkInfo() throws NoBenchmarkInfoException {
		List<ImageStoreBenchmarkInfo> imageStoreBenchmarkInfos = imageStoreBenchmarkInfoRepository
				.findAll();
		if ((imageStoreBenchmarkInfos == null) || (imageStoreBenchmarkInfos.size() < 1)) {
			logger.warn("getScale imageStoreBenchmarkInfos = null");
			throw new NoBenchmarkInfoException();
		}
		return imageStoreBenchmarkInfos.get(0);

	}

}
