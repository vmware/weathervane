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
import java.io.File;
import java.io.IOException;
import java.util.List;

import javax.annotation.PreDestroy;
import javax.imageio.ImageIO;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.core.JsonGenerationException;
import com.fasterxml.jackson.core.JsonParseException;
import com.fasterxml.jackson.databind.JsonMappingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.model.ImageStoreBenchmarkInfo;

/**
 * This is an implementation of the ImageStoreFacade that stores all images in a
 * single directory on the filesystem..
 * 
 * @author Hal
 * 
 */
public class ImageStoreFacadeFilesystemImpl extends ImageStoreFacadeBaseImpl {

	private static final Logger logger = LoggerFactory
			.getLogger(ImageStoreFacadeFilesystemImpl.class);

	// The values for these are injected in the Spring configuration
	private String baseDirectory;

	@PreDestroy
	public void preDestroy() {
		logger.info("ImageStoreFacadeMongodbImpl is being Destroyed!");
		stopServiceThreads();
	}

	protected String prefixGenerator(String entityName, long entityId, long imageId) {

		return entityName + "_" + entityId + "_" + imageId;
	}

	protected String computeDirectoryPath(String entityName, long imageId, boolean includePathHead) {
		String pathHead;
		if (includePathHead) {
			pathHead = baseDirectory + "/" + entityName + "/";
		} else {
			pathHead = entityName + "/";
		}

		// Pad the imageId out to 12 digits.
		String paddedId = StringUtils.leftPad(Long.toString(imageId), 12, '0');
		StringBuilder idPath = new StringBuilder(paddedId);

		/*
		 * Break the image id into subdirectories every 3 digits. That means a
		 * max of 1000 files/directories per subdirectory.
		 */
		idPath.insert(3, '/').insert(7, '/').insert(11, '/');

		return pathHead + idPath.toString();
	}

	protected void writeImageToFile(BufferedImage sourceImage, String filePrefix, String path,
			ImageStoreFacade.ImageSize size) throws IOException {
		String fileName = filePrefix + "_" + size + "." + this.getImageFormat();
		File outFile = new File(path, fileName);

		// Don't bother resizing for a full-size image
		BufferedImage finalImage = sourceImage;
		if (size != ImageSize.FULL) {
			finalImage = scaleImageToSize(sourceImage, size);
		}

		ImageIO.write(finalImage, this.getImageFormat(), outFile);
	}

	protected void writeBytesToFile(byte[] imageBytes, String filePrefix, String path,
			ImageStoreFacade.ImageSize size) throws IOException {
		String fileName = filePrefix + "_" + size + "." + this.getImageFormat();
		File outFile = new File(path, fileName);

		FileUtils.writeByteArrayToFile(outFile, imageBytes);

	}

	@Override
	protected void resizeAndSaveImage(ImageInfo imageInfo, byte[] imageBytes) throws IOException {
		String entityName = imageInfo.getEntitytype();
		long entityId = imageInfo.getEntityid();

		/*
		 * Determine the imagenum by finding out how many images are already
		 * store for this entity
		 */
		Long imageCount = imageInfoRepository.countByEntityidAndEntitytype(entityId, entityName);
		imageInfo.setImagenum(imageCount + 1);
		imageInfo.setFormat(getImageFormat());

		String filePrefix = prefixGenerator(entityName, entityId, imageCount + 1) + "_added";
		String path = computeDirectoryPath(entityName, entityId, false);

		imageInfo.setFilepath(path + "/" + filePrefix);
		/*
		 * Save the imageInfo. This will cause the image to get a unique id
		 * which will be the handle for the image
		 */
		imageInfo = imageInfoRepository.save(imageInfo);

		BufferedImage image = ImageIO.read(new ByteArrayInputStream(imageBytes));

		// Make sure that the path exists
		path = computeDirectoryPath(entityName, entityId, true);
		File pathDir = new File(path);
		if (!pathDir.exists()) {
			// The directory does not exist.
			pathDir.mkdirs();
		}

		logger.info("Writing image for " + entityName + " with id=" + entityId + " and imageId="
				+ imageCount + ". Path = " + path + ", filePrefix = " + filePrefix);
		// Write out a version for each image size
		for (ImageSize size : ImageStoreFacade.ImageSize.values()) {
			if (size != ImageSize.FULL) {
				writeImageToFile(image, filePrefix, path, size);
			} else {
				writeBytesToFile(imageBytes, filePrefix, path, size);
			}
		}

	}
	@Override
	protected void saveImage(ImageInfo imageInfo, byte[] imageBytes) throws IOException {
		String entityName = imageInfo.getEntitytype();
		long entityId = imageInfo.getEntityid();

		/*
		 * Determine the imagenum by finding out how many images are already
		 * store for this entity
		 */
		Long imageCount = imageInfoRepository.countByEntityidAndEntitytype(entityId, entityName);
		imageInfo.setImagenum(imageCount + 1);
		imageInfo.setFormat(getImageFormat());

		String filePrefix = prefixGenerator(entityName, entityId, imageCount + 1) + "_added";
		String path = computeDirectoryPath(entityName, entityId, false);

		imageInfo.setFilepath(path + "/" + filePrefix);
		/*
		 * Save the imageInfo. This will cause the image to get a unique id
		 * which will be the handle for the image
		 */
		imageInfo = imageInfoRepository.save(imageInfo);

		// Make sure that the path exists
		path = computeDirectoryPath(entityName, entityId, true);
		File pathDir = new File(path);
		if (!pathDir.exists()) {
			// The directory does not exist.
			pathDir.mkdirs();
		}

		logger.info("Writing image for " + entityName + " with id=" + entityId + " and imageId="
				+ imageCount + ". Path = " + path + ", filePrefix = " + filePrefix);
		writeBytesToFile(imageBytes, filePrefix, path, ImageSize.FULL);

	}
	
	@Override
	public ImageInfo addImage(ImageInfo imageInfo, BufferedImage fullImage, BufferedImage previewImage,
			BufferedImage thumbnailImage) throws IOException {
		logger.info("addImage with all bytes. Writing image for " + imageInfo.getEntitytype()
				+ " with id=" + imageInfo.getEntityid());

		String entityName = imageInfo.getEntitytype();
		long entityId = imageInfo.getEntityid();

		Long imageNum = imageInfo.getImagenum();
		if (imageNum == null) {
			/*
			 * Determine the imagenum by finding out how many images are already
			 * store for this entity
			 */
			imageNum = imageInfoRepository.countByEntityidAndEntitytype(entityId, entityName);
			imageInfo.setImagenum(imageNum);
			imageInfo.setFormat(getImageFormat());
		}

		String filePrefix = prefixGenerator(entityName, entityId, imageNum);
		String path = computeDirectoryPath(entityName, entityId, false);
		imageInfo.setFilepath(path + "/" + filePrefix);

		/*
		 * Save the imageInfo.
		 */
		imageInfo = imageInfoRepository.save(imageInfo);

		// Make sure that the path exists
		path = computeDirectoryPath(entityName, entityId, true);
		File pathDir = new File(path);
		if (!pathDir.exists()) {
			// The directory does not exist.
			pathDir.mkdirs();
		}

		logger.info("Writing image for " + entityName + " with id=" + entityId + " and imageId="
				+ imageNum + ". Path = " + path + ", filePrefix = " + filePrefix);
		if (fullImage != null) {
			writeBytesToFile(randomizeImage(fullImage), filePrefix, path, ImageSize.FULL);
		}

		if (previewImage != null) {
			writeBytesToFile(randomizeImage(previewImage), filePrefix, path, ImageSize.PREVIEW);
		}

		if (thumbnailImage != null) {
			writeBytesToFile(randomizeImage(thumbnailImage), filePrefix, path, ImageSize.THUMBNAIL);
		}
		return imageInfo;
	}

	@Override
	public void addImages(List<ImageInfo> imageInfos, List<BufferedImage> fullImages,
			List<BufferedImage> previewImages, List<BufferedImage> thumbnailImages) throws IOException {
		logger.info("addImages with all bytes.");
		BufferedImage fullImage = null;
		BufferedImage previewImage = null;
		BufferedImage thumbnailImage = null;

		/*
		 * Prepare the images for insert. need to save the ImageInfos
		 * individually to cause the images to get unique ids
		 */
		int index = 0;
		for (ImageInfo anImageInfo : imageInfos) {

			if ((fullImages != null) && (fullImages.size() > 0)
					&& (fullImages.get(index) != null)) {
				fullImage = fullImages.get(index);
			} else {
				fullImage = null;
			}

			if ((previewImages != null) && (previewImages.size() > 0)
					&& (previewImages.get(index) != null)) {
				previewImage = previewImages.get(index);
			} else {
				previewImage = null;
			}

			if ((thumbnailImages != null) && (thumbnailImages.size() > 0)
					&& (thumbnailImages.get(index) != null)) {
				thumbnailImage = thumbnailImages.get(index);
			} else {
				thumbnailImage = null;
			}

			this.addImage(anImageInfo, fullImage, previewImage, thumbnailImage);
			index++;
		}
	}

	@Override
	public byte[] retrieveImage(String imageHandle, ImageSize size) throws NoSuchImageException,
			IOException {
		// Get the imageInfo for the image
		logger.info("Finding imageInfo for filepath = " + imageHandle);
		List<ImageInfo> imageInfos = imageInfoRepository.findByFilepath(imageHandle);
		if ((imageInfos == null) || imageInfos.isEmpty()) {
			throw new NoSuchImageException("No matching images for filepath " + imageHandle);
		}
		ImageInfo theImageInfo = imageInfos.get(0);

		String entityName = theImageInfo.getEntitytype();
		Long entityId = theImageInfo.getEntityid();
		Long imageId = theImageInfo.getImagenum();

		String imagePrefix = prefixGenerator(entityName, entityId, imageId);

		String fileName = imagePrefix + "_" + size + "." + this.getImageFormat();
		String path = computeDirectoryPath(entityName, entityId, true);

		logger.info("Opening image file with path " + path + ", size=" + size + ", filename = "
				+ fileName);

		/*
		 * Keep trying to open the file, going down in size until there are no
		 * sizes left to try.
		 */
		File imageFile = new File(path, fileName);

		while (!imageFile.exists()) {
			/*
			 * See if other smaller sizes exist
			 */
			switch (size) {
			case FULL:
				size = ImageSize.PREVIEW;
				fileName = imageHandle + "_" + size + "." + this.getImageFormat();
				imageFile = new File(path, fileName);
				break;

			case PREVIEW:
				size = ImageSize.THUMBNAIL;
				fileName = imageHandle + "_" + size + "." + this.getImageFormat();
				imageFile = new File(path, fileName);
				break;

			case THUMBNAIL:
				throw new NoSuchImageException("No images with entityName " + entityName
						+ ", entityId  " + entityId + ", imageId " + imageId + " exist at path "
						+ path);
			}

		}

		logger.info("Reading image file with path " + path + ", size=" + size + ", filename = "
				+ fileName);
		byte[] retBytes = FileUtils.readFileToByteArray(imageFile);
		return retBytes;
	}

	@Override
	public void resetImageStore() throws IOException {
		FileUtils.cleanDirectory(new File(baseDirectory));
	}

	public String getBaseDirectory() {
		return baseDirectory;
	}

	public void setBaseDirectory(String baseDirectory) {
		this.baseDirectory = baseDirectory;
	}

	@Override
	public void clearNonpreloadedImages() {
		logger.info("clearNonPreloadedImages");
		imageInfoRepository.deleteByPreloaded(false);
	}

	@Override
	public void setBenchmarkInfo(ImageStoreBenchmarkInfo imageStoreBenchmarkInfo) {
		imageStoreBenchmarkInfo.setId("0");

		/* save the scale in a file */
		String fileName = "ImageStoreBenchmarkInfo.json";
		File outFile = new File(baseDirectory, fileName);

		ObjectMapper objectMapper = new ObjectMapper();
		try {
			objectMapper.writeValue(outFile, imageStoreBenchmarkInfo);
		} catch (JsonGenerationException e) {
			logger.warn("setScale: JsonGenerationException " + e.getMessage());
		} catch (JsonMappingException e) {
			logger.warn("setScale: JsonMappingException " + e.getMessage());
		} catch (IOException e) {
			logger.warn("setScale: IOException " + e.getMessage());
		}

	}

	@Override
	public ImageStoreBenchmarkInfo getBenchmarkInfo() {
		/* read the scale from a file */
		String fileName = "ImageStoreBenchmarkInfo.json";
		File outFile = new File(baseDirectory, fileName);

		ObjectMapper objectMapper = new ObjectMapper();
		ImageStoreBenchmarkInfo imageStoreBenchmarkInfo = null;
		try {
			imageStoreBenchmarkInfo = objectMapper
					.readValue(outFile, ImageStoreBenchmarkInfo.class);
		} catch (JsonParseException e) {
			logger.error("getScale: JsonParseException " + e.getMessage());
			System.exit(-1);
		} catch (JsonMappingException e) {
			logger.error("getScale: JsonMappingException " + e.getMessage());
			System.exit(-1);
		} catch (IOException e) {
			logger.error("getScale: IOException " + e.getMessage());
			System.exit(-1);
		}
		return imageStoreBenchmarkInfo;
	}

}
