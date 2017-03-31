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
package com.vmware.weathervane.auction.dbloader;

import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;

import javax.imageio.ImageIO;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;
import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;

import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade.ImageSize;

/**
 * Hello world!
 * 
 */
public class ImageManager {
	private static String[] supportedImageFormats = { "jpg", "png", "gif" };
	private static String imageDirDefault = "images";

	private static ImageStoreFacade imageStore;

	private static final Logger logger = LoggerFactory.getLogger(ImageManager.class);

	public static void usage() {

		System.out.println("Usage information for the Auction Manager:");

	}

	public static void main(String[] args) throws IOException {
		Option i = new Option("i", "image", true, "The name of the image file  or directory of files to be prepared for use in the benchmark.");
		i.setRequired(true);

		Option d = new Option("d", "imagedir", true,
				"The Directory in which to place the images for later use by the dbLoader");

		Options cliOptions = new Options();
		cliOptions.addOption(i);
		cliOptions.addOption(d);

		CommandLine cliCmd = null;
		CommandLineParser cliParser = new PosixParser();
		try {
			cliCmd = cliParser.parse(cliOptions, args);
		} catch (ParseException ex) {
			System.err.println("DBLoader.  Caught ParseException " + ex.getMessage());
			return;
		}

		String imageFilenameString = cliCmd.getOptionValue('i');
		String imageDirString = cliCmd.getOptionValue('d', imageDirDefault);

		ApplicationContext context = new ClassPathXmlApplicationContext(
				new String[] { "imageManager-application-context.xml" });
		imageStore = (ImageStoreFacade) context.getBean("imageStoreFacade");

		/*
		 * Read in the image from the file
		 */
		File imageFile = new File(imageFilenameString);
		if (imageFile.isFile()) {
			// handle a single file		
			String fileNameString = imageFile.getName();
			// Get the filename prefix (After last '/' and before last '.'
			String[] pathElements = fileNameString.split("/");
			String fileName = pathElements[pathElements.length - 1];
			String fileNamePrefix = fileName.substring(0, fileName.lastIndexOf('.'));
			String fileNameSuffix = fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase();

			if (!fileNameSuffix.equals("jpg") && !fileNameSuffix.equals("jpeg") && !fileNameSuffix.equals("png") && !fileNameSuffix.equals("gif")){
				System.out.println("File " + fileName + " not an image");
				return;
			}
			
			BufferedImage originalImage = ImageIO.read(imageFile);

			/*
			 * Now write version of the file for each of the supported image types
			 * and sizes
			 */ 
			for (ImageSize size : ImageSize.values()) {
				
				BufferedImage scaledImage = originalImage;
				if (size != ImageSize.FULL) {
					scaledImage = imageStore.scaleImageToSize(originalImage, size);
				}
				
				for (String imageFormat : supportedImageFormats) {	
					File outFile = new File(imageDirString, fileNamePrefix + "_" + size + "." + imageFormat);
					if ((size == ImageSize.FULL) && (imageFormat.equals(fileNameSuffix))) {
						FileUtils.copyFile(imageFile, outFile);
					} else {
						ImageIO.write(scaledImage, imageFormat, outFile);
					}
				}
			}
		} else if (imageFile.isDirectory()) {
			File[] imageFiles = imageFile.listFiles();
			for (File anImageFile : imageFiles) {

				String fileNameString = anImageFile.getName();
				System.out.println("Working on file " + fileNameString);

				// Get the filename prefix (After last '/' and before last '.'
				String[] pathElements = fileNameString.split("/");
				String fileName = pathElements[pathElements.length - 1];
				String fileNamePrefix = fileName.substring(0, fileName.lastIndexOf('.'));
				String fileNameSuffix = fileName.substring(fileName.lastIndexOf('.') + 1)
						.toLowerCase();

				if (!fileNameSuffix.equals("jpg") && !fileNameSuffix.equals("jpeg")
						&& !fileNameSuffix.equals("png") && !fileNameSuffix.equals("gif")) {
					System.out.println("File " + fileName + " with prefix " + fileNamePrefix
							+ " and suffix " + fileNameSuffix + " is not an image");
					continue;
				}

				BufferedImage originalImage = ImageIO.read(anImageFile);

				/*
				 * Now write version of the file for each of the supported image
				 * types and sizes
				 */
				for (ImageSize size : ImageSize.values()) {
					BufferedImage scaledImage = originalImage;
					if (size != ImageSize.FULL) {
						scaledImage = imageStore.scaleImageToSize(originalImage, size);
					}

					for (String imageFormat : supportedImageFormats) {
						File outFile = new File(imageDirString, fileNamePrefix + "_" + size + "."
								+ imageFormat);
						if ((size == ImageSize.FULL) && (imageFormat.equals(fileNameSuffix))) {
							FileUtils.copyFile(anImageFile, outFile);
						} else {
							ImageIO.write(scaledImage, imageFormat, outFile);
						}
					}

				}
			}
		}
	}
}