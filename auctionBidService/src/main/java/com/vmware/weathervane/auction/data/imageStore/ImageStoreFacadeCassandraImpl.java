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
import java.util.List;
import java.util.UUID;

import javax.imageio.ImageIO;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.data.cassandra.core.CassandraOperations;

import com.datastax.driver.core.querybuilder.QueryBuilder;
import com.vmware.weathervane.auction.data.imageStore.model.ImageFull;
import com.vmware.weathervane.auction.data.imageStore.model.ImageFull.ImageFullKey;
import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.imageStore.model.ImagePreview;
import com.vmware.weathervane.auction.data.imageStore.model.ImagePreview.ImagePreviewKey;
import com.vmware.weathervane.auction.data.imageStore.model.ImageThumbnail;
import com.vmware.weathervane.auction.data.imageStore.model.ImageThumbnail.ImageThumbnailKey;
import com.vmware.weathervane.auction.data.model.ImageStoreBenchmarkInfo;
import com.vmware.weathervane.auction.data.repository.event.ImageStoreBenchmarkInfoRepository;
import com.vmware.weathervane.auction.data.repository.image.ImageFullRepository;
import com.vmware.weathervane.auction.data.repository.image.ImagePreviewRepository;
import com.vmware.weathervane.auction.data.repository.image.ImageThumbnailRepository;

/**
 * This is an implementation of the ImageStoreFacade that stores all images in a
 * collection in Cassandra.
 * 
 * @author Hal
 * 
 */
public class ImageStoreFacadeCassandraImpl extends ImageStoreFacadeBaseImpl {

	private static final Logger logger = LoggerFactory.getLogger(ImageStoreFacadeCassandraImpl.class);

	@Autowired
	private ImageFullRepository imageFullRepository;

	@Autowired
	private ImagePreviewRepository imagePreviewRepository;

	@Autowired
	private ImageThumbnailRepository imageThumbnailRepository;

	@Autowired
	private ImageStoreBenchmarkInfoRepository imageStoreBenchmarkInfoRepository;
	
	@Autowired
	@Qualifier("cassandraImageTemplate")
	private CassandraOperations cassandraOperations;

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

		UUID imageId = imageInfo.getImageId();

		boolean preloaded = imageInfo.getKey().isPreloaded();

		// put the full size image on the queue to be written
		ImageFullKey ifKey = new ImageFullKey();
		ifKey.setImageId(imageId);
		ifKey.setPreloaded(preloaded);
		ImageFull imageFull = new ImageFull();
		imageFull.setKey(ifKey);
		imageFull.setImage(imageBytes);
		imageFullRepository.save(imageFull);

		BufferedImage image = ImageIO.read(new ByteArrayInputStream(imageBytes));

		// put the preview size image on the queue to be written
		ImagePreviewKey ipKey = new ImagePreviewKey();
		ipKey.setImageId(imageId);
		ipKey.setPreloaded(preloaded);
		ImagePreview imagePreview = new ImagePreview();
		imagePreview.setKey(ipKey);
		imagePreview.setImage(resizeImage(image, ImageSize.PREVIEW));
		imagePreviewRepository.save(imagePreview);

		// put the thumbnail size image on the queue to be written
		ImageThumbnailKey itKey = new ImageThumbnailKey();
		itKey.setImageId(imageId);
		itKey.setPreloaded(preloaded);
		ImageThumbnail imageThumbnail = new ImageThumbnail();
		imageThumbnail.setKey(itKey);
		imageThumbnail.setImage(resizeImage(image, ImageSize.THUMBNAIL));
		imageThumbnailRepository.save(imageThumbnail);
	}
	
	@Override
	protected void saveImage(ImageInfo imageInfo, byte[] imageBytes) throws IOException {
		/*
		 * First save the imageInfo. This will cause the image to get a unique
		 * id which will be used as the handle
		 */
		imageInfo.setFormat(getImageFormat());
		imageInfo = imageInfoRepository.save(imageInfo);

		UUID imageId = imageInfo.getImageId();

		boolean preloaded = imageInfo.getKey().isPreloaded();

		// save the full size image 
		ImageFullKey ifKey = new ImageFullKey();
		ifKey.setImageId(imageId);
		ifKey.setPreloaded(preloaded);
		ImageFull imageFull = new ImageFull();
		imageFull.setKey(ifKey);
		imageFull.setImage(imageBytes);
		imageFullRepository.save(imageFull);
		
	}
	
	@Override
	public ImageInfo addImage(ImageInfo imageInfo, BufferedImage fullImage, BufferedImage previewImage,
			BufferedImage thumbnailImage) throws IOException {
		logger.info("addImage with all bytes. Writing image for " + imageInfo.getKey().getEntitytype()
				+ " with id=" + imageInfo.getKey().getEntityid());

		/*
		 * First save the imageInfo. This will cause the image to get a unique
		 * id which will be used as the handle
		 */
		imageInfo.setFormat(getImageFormat());
		imageInfo = imageInfoRepository.save(imageInfo);
		UUID imageId = imageInfo.getImageId();
		boolean preloaded = imageInfo.getKey().isPreloaded();

		// put the full size image on the queue to be written
		if (fullImage != null) {
			logger.debug("addImage bytes adding full image for " + imageInfo.getKey().getEntitytype() + ":"
					+ imageInfo.getKey().getEntityid());

			// Randomize the image
			ImageFullKey ifKey = new ImageFullKey();
			ifKey.setImageId(imageId);
			ifKey.setPreloaded(preloaded);			
			ImageFull imageFull = new ImageFull();
			imageFull.setKey(ifKey);
			imageFull.setImage(randomizeImage(fullImage));
			imageFullRepository.save(imageFull);
		}

		// put the preview size image on the queue to be written
		if (previewImage != null) {
			logger.debug("addImage bytes adding preview image for " + imageInfo.getKey().getEntitytype() + ":"
					+ imageInfo.getKey().getEntityid());
			// Randomize the image
			ImagePreviewKey ipKey = new ImagePreviewKey();
			ipKey.setImageId(imageId);
			ipKey.setPreloaded(preloaded);
			ImagePreview imagePreview = new ImagePreview();
			imagePreview.setKey(ipKey);
			imagePreview.setImage(randomizeImage(previewImage));
			imagePreviewRepository.save(imagePreview);
		}

		// put the thumbnail size image on the queue to be written
		if (thumbnailImage != null) {
			logger.debug("addImage bytes adding thumbnail image for " + imageInfo.getKey().getEntitytype() + ":"
					+ imageInfo.getKey().getEntityid());
			
			// Randomize the image
			ImageThumbnailKey itKey = new ImageThumbnailKey();
			itKey.setImageId(imageId);
			itKey.setPreloaded(preloaded);
			ImageThumbnail imageThumbnail = new ImageThumbnail();
			imageThumbnail.setKey(itKey);
			imageThumbnail.setImage(randomizeImage(thumbnailImage));
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
	public byte[] retrieveImage(UUID imageHandle, ImageSize size) throws NoSuchImageException,
			IOException {
		logger.info("retrieveImage imageHandle = " + imageHandle + ", imageSize = " + size);
		switch (size) {
		case THUMBNAIL:
			List<ImageThumbnail> thumbs = imageThumbnailRepository.findByKeyImageId(imageHandle);
			if (thumbs == null) {
				logger.warn("retrieveImage thumbs = null, imageHandle = " + imageHandle
						+ ", imageSize = " + size);
				throw new NoSuchImageException();
			}
			return thumbs.get(0).getImage().array();

		case PREVIEW:
			List<ImagePreview> previews = imagePreviewRepository.findByKeyImageId(imageHandle);
			if (previews == null) {
				logger.warn("retrieveImage previews = null, imageHandle = " + imageHandle
						+ ", imageSize = " + size);
				throw new NoSuchImageException();
			}
			return previews.get(0).getImage().array();

		default:
			List<ImageFull> fulls = imageFullRepository.findByKeyImageId(imageHandle);
			if (fulls == null) {
				logger.warn("retrieveImage fulls = null, imageHandle = " + imageHandle
						+ ", imageSize = " + size);
				throw new NoSuchImageException();
			}
			return fulls.get(0).getImage().array();
		}
	}

	@Override
	public void clearNonpreloadedImages() {
		logger.info("clearNonPreloadedImages");
		imageFullRepository.deleteByPreloaded(false);
		imagePreviewRepository.deleteByPreloaded(false);
		imageThumbnailRepository.deleteByPreloaded(false);
		imageInfoRepository.deleteByPreloaded(false);
	}

	@Override
	public void resetImageStore() throws IOException {
		// empty tables
		cassandraOperations.execute(QueryBuilder.truncate("image_info"));
		cassandraOperations.execute(QueryBuilder.truncate("image_full"));
		cassandraOperations.execute(QueryBuilder.truncate("image_preview"));
		cassandraOperations.execute(QueryBuilder.truncate("image_thumbnail"));
	}

	@Override
	public void setBenchmarkInfo(ImageStoreBenchmarkInfo imageStoreBenchmarkInfo) {

		imageStoreBenchmarkInfoRepository.save(imageStoreBenchmarkInfo);
	}

	@Override
	public ImageStoreBenchmarkInfo getBenchmarkInfo() throws NoBenchmarkInfoException {
		List<ImageStoreBenchmarkInfo> imageStoreBenchmarkInfos = (List<ImageStoreBenchmarkInfo>) imageStoreBenchmarkInfoRepository.findAll();
		if ((imageStoreBenchmarkInfos == null) || (imageStoreBenchmarkInfos.size() < 1)) {
			logger.warn("getScale imageStoreBenchmarkInfos = null");
			throw new NoBenchmarkInfoException();
		}
		return imageStoreBenchmarkInfos.get(0);

	}

}
