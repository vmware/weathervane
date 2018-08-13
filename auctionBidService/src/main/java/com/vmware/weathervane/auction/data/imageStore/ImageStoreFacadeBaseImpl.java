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

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.Transparency;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import javax.imageio.ImageIO;
import javax.inject.Inject;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.repository.ImageInfoRepository;

/**
 * This is an implementation of the ImageStoreFacade that stores all images in a
 * single directory on the filesystem..
 * 
 * @author Hal
 *
 */
public abstract class ImageStoreFacadeBaseImpl implements ImageStoreFacade {

	private static final Logger logger = LoggerFactory.getLogger(ImageStoreFacadeBaseImpl.class);

	private String imageFormat;

	private int thumbnailWidth;
	private int thumbnailHeight;
	private int previewWidth;
	private int previewHeight;
	private int addImageQueueSize;

	protected static long imageInfoGets = 0;

	private Random randomGen = new Random();

	@Inject
	protected ImageInfoRepository imageInfoRepository;

	@Inject
	private ImageInfoCacheFacade imageInfoCacheFacade;

	/*
	 * Queue to hold imgaes that are ready to be written out to the image store.
	 * The images are removed and written by a background thread.
	 */
	protected BlockingQueue<ImageQueueHolder> imageAddQueue;

	protected boolean randomizeImages = true;

	/*
	 * The number of threads that will handle the writing of each image size
	 */
	protected boolean useImageWriters = true;
	protected int numImageWriters = 10;

	// objects to manage the image queues and their threads
	protected List<ImageWriter> imageWriters = new ArrayList<ImageWriter>();
	protected List<Thread> imageWriterThreads = new ArrayList<Thread>();

	@PreDestroy
	public void preDestroy() {
		stopServiceThreads();
		long imageInfoMisses = ImageInfoCacheFacade.getImageInfoMisses();
		double imageInfoMissRate = imageInfoMisses / (double) imageInfoGets;

		logger.warn("ImageInfo Cache Stats: ");
		logger.warn("ImageInfos.  Gets = " + imageInfoGets + ", misses = " + imageInfoMisses
				+ ", miss rate = " + imageInfoMissRate);

	}

	@Override
	public void stopServiceThreads() {
		logger.info("ImageStoreFacadeMongodbImpl stopServiceThreads");
		for (ImageWriter imageWriter : imageWriters) {
			imageWriter.kill();
		}
		imageWriters.clear();
	}

	@PostConstruct
	private void startServiceThreads() {
		logger.info("startServiceThreads");

		if (useImageWriters) {
			imageAddQueue = new LinkedBlockingQueue<ImageStoreFacadeBaseImpl.ImageQueueHolder>(
					addImageQueueSize);

			// Start the image writer threads.
			for (int i = 0; i < numImageWriters; i++) {
				ImageWriter imageWriter = new ImageWriter();
				Thread imageWriterThread = new Thread(imageWriter, "imageWriter" + i);
				imageWriterThreads.add(imageWriterThread);

				imageWriters.add(imageWriter);

				imageWriterThread.start();
			}
		}
	}

	/**
	 * Computes the final dimensions for a given image scaled to a specific size
	 * but preserving the aspect ratio
	 * 
	 * @param image
	 * @param size
	 * @return The size that the image should be scaled to fit in the size and
	 *         preserve the aspect ratio.
	 */
	protected ImageDimensions computeScalePreserveAspectRatio(BufferedImage image, ImageSize size) {
		ImageDimensions finalDimensions = new ImageDimensions();

		int sourceWidth = image.getWidth();
		int sourceHeight = image.getHeight();

		int targetWidth = 0;
		int targetHeight = 0;

		int finalWidth;
		int finalHeight;

		switch (size) {
		case FULL:
			finalDimensions.setHeight(sourceHeight);
			finalDimensions.setWidth(sourceWidth);
			return finalDimensions;

		case PREVIEW:
			targetHeight = previewHeight;
			targetWidth = previewWidth;
			break;

		case THUMBNAIL:
			targetHeight = thumbnailHeight;
			targetWidth = thumbnailWidth;
			break;
		}

		// First try scaling by setting the finalWidth to the target width
		finalWidth = targetWidth;
		finalHeight = (int) (sourceHeight * ((double) targetWidth / sourceWidth));

		// Check whether we ended up with a height that exceeds the target.
		if (finalHeight > targetHeight) {
			// Rescale setting the height to the max
			finalHeight = targetHeight;
			finalWidth = (int) (sourceWidth * ((double) targetHeight / sourceHeight));
		}

		finalDimensions.setHeight(finalHeight);
		finalDimensions.setWidth(finalWidth);
		return finalDimensions;
	}

	/***
	 * Randomize an image stored as an array of bytes. The goal is to avoid
	 * enable deduplication of the image files. This method makes the image
	 * unrenderable, but images added during a run are not actually accessed or
	 * rendered.
	 * Insert a random byte every 256 bytes
	 */
	protected byte[] randomizeImageBytes(byte[] img) throws IOException {
		
		int stepSize =  256;
		for (int i = stepSize; i < img.length; i+= stepSize) {
			img[i] = (byte) randomGen.nextInt();
		}
		
		return img;
	}

	/***
	 * This method randomizes the contents of an image by putting random values
	 * in every n-th pixel.
	 * 
	 * @param img
	 * @throws IOException
	 */
	protected byte[] randomizeImage(BufferedImage img) throws IOException {
		int width = img.getWidth();
		int height = img.getHeight();
		final int xSize = 1;
		final int ySize = height / 2;
		final int xStepSize = 48;

		Random random = new Random();

		Graphics2D graphics2d = (Graphics2D) img.getGraphics();
		// create random image pixel by pixel
		final float luminance = 0.9f;
		for (int y = 0; y < height; y += ySize) {
			for (int x = 0; x < width; x += xStepSize) {

				final float hue = random.nextFloat();
				final float saturation = (random.nextInt(2000) + 1000) / 10000f;
				Color color = Color.getHSBColor(hue, saturation, luminance);

				graphics2d.setColor(color);
				graphics2d.fillRect(x, y, xSize, ySize);
			}
		}

		graphics2d.dispose();

		ByteArrayOutputStream baos = new ByteArrayOutputStream();

		ImageIO.write(img, "jpg", baos);
		baos.flush();
		byte[] byteImage = baos.toByteArray();
		baos.close();

		return byteImage;

	}

	protected byte[] getRandomImageBytes(ImageSize size) throws IOException {
		Random random = new Random();
		final int blockSize = 10;

		int width;
		int height;
		switch (size) {
		case PREVIEW:
			width = 260;
			height = 350;
			break;

		case FULL:
			width = 770;
			height = 1020;
			break;

		default:
			width = 80;
			height = 100;
			break;
		}

		// create buffered image object img
		BufferedImage img = new BufferedImage(width, height, BufferedImage.TYPE_3BYTE_BGR);
		Graphics2D graphics2d = (Graphics2D) img.getGraphics();
		// create random image pixel by pixel
		final float luminance = 0.9f;
		for (int y = 0; y < height; y += blockSize) {
			for (int x = 0; x < width; x += blockSize) {

				final float hue = random.nextFloat();
				final float saturation = (random.nextInt(2000) + 1000) / 10000f;
				Color color = Color.getHSBColor(hue, saturation, luminance);

				graphics2d.setColor(color);
				graphics2d.fillRect(x, y, blockSize, blockSize);
			}
		}

		graphics2d.dispose();

		ByteArrayOutputStream baos = new ByteArrayOutputStream();

		ImageIO.write(img, "jpg", baos);
		baos.flush();
		byte[] byteImage = baos.toByteArray();
		baos.close();

		return byteImage;
	}

	public List<ImageInfo> getImageInfos(String entityType, Long entityId) {
		imageInfoGets++;
		logger.info("getImageInfos entityType = " + entityType + ", entityId = " + entityId);
		return imageInfoCacheFacade.getImageInfos(entityType, entityId);
	}

	/**
	 * 
	 * 
	 * @param image
	 * @param size
	 * @return A copy of the image scaled to the given size while preserving the
	 *         aspect ratio
	 */
	@Override
	public BufferedImage scaleImageToSize(BufferedImage sourceImage, ImageSize size) {
		ImageDimensions finalDimensions = computeScalePreserveAspectRatio(sourceImage, size);

		int imageType = (sourceImage.getTransparency() == Transparency.OPAQUE) ? BufferedImage.TYPE_INT_RGB
				: BufferedImage.TYPE_INT_ARGB;

		BufferedImage destImage = new BufferedImage(finalDimensions.getWidth(),
				finalDimensions.getHeight(), imageType);

		Graphics2D g2d = destImage.createGraphics();

		g2d.setRenderingHint(RenderingHints.KEY_INTERPOLATION,
				RenderingHints.VALUE_INTERPOLATION_BILINEAR);
		g2d.drawImage(sourceImage, 0, 0, finalDimensions.getWidth(), finalDimensions.getHeight(),
				null);
		g2d.dispose();

		return destImage;
	}

	@Override
	public void clearNonpreloadedImages() {
		// default is no-op
		logger.info("clearNonPreloadedImages");

	}

	@Override
	public void addImages(List<ImageInfo> imageInfos, List<BufferedImage> fullImages,
			List<BufferedImage> previewImages, List<BufferedImage> thumbnailImages)
			throws IOException {
	}

	protected abstract void resizeAndSaveImage(ImageInfo imageInfo, byte[] imageBytes)
			throws IOException;

	protected abstract void saveImage(ImageInfo imageInfo, byte[] imageBytes) throws IOException;

	@Override
	public ImageInfo addImage(ImageInfo imageInfo, byte[] imageBytes) throws IOException,
			ImageQueueFullException {

		if (useImageWriters) {
			ImageQueueHolder imageQueueHolder = new ImageQueueHolder(new ImageInfo(imageInfo),
					imageBytes);
			boolean imageAdded = imageAddQueue.offer(imageQueueHolder);
			if (!imageAdded) {
				throw new ImageQueueFullException(
						"No space in the imageWriter queue. Already contains "
								+ imageAddQueue.size() + " images to be written");
			}
			imageInfo.setId("pending");
		} else {
			byte[] randomizedImage = imageBytes;
			if (randomizeImages) {
				randomizedImage = randomizeImageBytes(imageBytes);
			}
			saveImage(imageInfo, randomizedImage);
		}
		return imageInfo;
	}

	@Override
	public String getImageFormat() {
		return imageFormat;
	}

	@Override
	public void setImageFormat(String imageFormat) {
		this.imageFormat = imageFormat;
	}

	@Override
	public void setThumbnailWidth(int thumbnailWidth) {
		this.thumbnailWidth = thumbnailWidth;
	}

	@Override
	public void setThumbnailHeight(int thumbnailHeight) {
		this.thumbnailHeight = thumbnailHeight;
	}

	@Override
	public void setPreviewWidth(int previewWidth) {
		this.previewWidth = previewWidth;
	}

	@Override
	public void setPreviewHeight(int previewHeight) {
		this.previewHeight = previewHeight;
	}

	public int getThumbnailWidth() {
		return thumbnailWidth;
	}

	public int getThumbnailHeight() {
		return thumbnailHeight;
	}

	public int getPreviewWidth() {
		return previewWidth;
	}

	public int getPreviewHeight() {
		return previewHeight;
	}

	public int getNumImageWriters() {
		return numImageWriters;
	}

	public void setNumImageWriters(int numImageWriters) {
		this.numImageWriters = numImageWriters;
	}

	public boolean isUseImageWriters() {
		return useImageWriters;
	}

	public void setUseImageWriters(boolean use) {
		useImageWriters = use;
	}

	@Override
	public List<Thread> getImageWriterThreads() {
		return imageWriterThreads;
	}

	public int getAddImageQueueSize() {
		return addImageQueueSize;
	}

	public void setAddImageQueueSize(int addImageQueueSize) {
		this.addImageQueueSize = addImageQueueSize;
	}

	public boolean isRandomizeImages() {
		return randomizeImages;
	}

	public void setRandomizeImages(boolean randomizeImages) {
		this.randomizeImages = randomizeImages;
	}

	/**
	 * The ImageQueueHolder is used when queuing images to be added by the
	 * ImageWriter threads
	 * 
	 * @author hrosenbe
	 * 
	 */
	protected class ImageQueueHolder {

		private ImageInfo imageInfo;
		private byte[] image;

		public ImageQueueHolder() {
			logger.debug("ImageQueueHolder constructor");
		}

		public ImageQueueHolder(ImageInfo theImageInfo, byte[] theImage) {
			logger.debug("ImageQueueHolder constructor with params");
			imageInfo = theImageInfo;
			image = theImage;
		}

		public void setImageInfo(ImageInfo theImageInfo) {
			imageInfo = theImageInfo;
		}

		public ImageInfo getImageInfo() {
			return imageInfo;
		}

		public void setImage(byte[] theImage) {
			image = theImage;
		}

		public byte[] getImage() {
			return image;
		}

	}

	/**
	 * The FullImageWriter is responsible for writing the full size images into
	 * the image store. It just takes the images off of the full image queue and
	 * writes them out
	 * 
	 * @author hrosenbe
	 * 
	 */
	protected class ImageWriter implements Runnable {

		private volatile boolean notKilled = true;

		public ImageWriter() {
			logger.debug("ImageWriter constructor");
		}

		public void kill() {
			logger.debug("ImageWriter::kill");
			notKilled = false;
		}

		@Override
		public void run() {
			logger.info("ImageWriter run()");
			ImageQueueHolder nextImage;
			/*
			 * Repeat the write process forever until the thread is told to die
			 */
			while (notKilled || (!imageAddQueue.isEmpty())) {

				nextImage = null;

				try {
					nextImage = imageAddQueue.poll(10, TimeUnit.SECONDS);
				} catch (InterruptedException e) {
					logger.warn("ImageWriter interrupted before an image became available.");
				}

				if (nextImage != null) {
					logger.debug("ImageWriter got image for imageId "
							+ nextImage.getImageInfo().getId());
					try {
						byte[] randomizedImage = nextImage.getImage();
						if (randomizeImages) {
							randomizedImage = randomizeImageBytes(nextImage.getImage());
						}

						saveImage(nextImage.getImageInfo(), randomizedImage);
					} catch (IOException e) {
						logger.warn("Got IOException when resizing and saving image with id "
								+ nextImage.getImageInfo().getId());
						e.printStackTrace();
					}
				}
			}

		}

	}

}
