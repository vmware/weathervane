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
package com.vmware.weathervane.auction.controllers;

import java.io.IOException;

import javax.annotation.PreDestroy;
import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.http.HttpServletRequest;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;

import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade.ImageSize;
import com.vmware.weathervane.auction.service.ItemService;

@Controller
@RequestMapping(value = "/image")
public class ImageController extends BaseController {
	private static final Logger logger = LoggerFactory.getLogger(ImageController.class);

	/*
	 * Variables used for computing cache miss rates on itemImages
	 */
	private static long thumbnailGets = 0;
	private static long previewGets = 0;
	private static long fullGets = 0;
	
	/*
	 * Method to print stats for cache misses at end of runs
	 */
	@PreDestroy
	private void printImageCacheStats() {
		//		double previewMissRate = itemService.getPreviewMisses() / (double) previewGets;
		//		double fullMissRate = itemService.getFullMisses() / (double) fullGets;
		
		if (thumbnailGets > 0) {
			double thumbnailMissRate = itemService.getThumbnailMisses() / (double) thumbnailGets;
			logger.warn("Image Cache Stats: ");
			logger.warn("Thumbnail images.  Gets = " + thumbnailGets + ", misses = " + itemService.getThumbnailMisses() + ", miss rate = " + thumbnailMissRate);
		}
		
		//		logger.warn("Preview images.  Gets = " + previewGets + ", misses = " + itemService.getPreviewMisses() + ", miss rate = " + previewMissRate);
		//		logger.warn("Full images.  Gets = " + fullGets + ", misses = " + itemService.getFullMisses() + ", miss rate = " + fullMissRate);
	}

	private ItemService itemService;

	@Inject
	@Named("itemService")
	public void setItemService(ItemService itemService) {
		this.itemService = itemService;
	}
		
	@RequestMapping(value = "/**", method = RequestMethod.GET)
	public HttpEntity<byte[]> getImageForItem(HttpServletRequest request,
			@RequestParam(value = "size", required = false) ImageStoreFacade.ImageSize size) throws IOException {

		String imagePath = request.getRequestURI();
		imagePath = imagePath.replace("/auction/image/Item", "Item");
		imagePath = imagePath.replace(".jpg", "");
		logger.debug("getImageForItem, imagePath = " + imagePath + ", size = " + size);
			
		if (size == null) {
			size = ImageSize.FULL;
		}
		byte[] image = null;
		/*
		 * This method defers to methods for each size.  This allows
		 * for independent caches.
		 */
		if (size == ImageSize.PREVIEW) {
			previewGets++;
			image = itemService.getPreviewImageForItem(0, imagePath);
		} else if (size == ImageSize.THUMBNAIL) {
			thumbnailGets++;
			image = itemService.getThumbnailImageForItem(0, imagePath);
		} else {
			fullGets++;
			image = itemService.getFullImageForItem(0, imagePath);
		}

		HttpHeaders headers = new HttpHeaders();
		headers.setContentType(MediaType.IMAGE_JPEG);
		headers.setContentLength(image.length);
		
		return new HttpEntity<byte[]>(image, headers);
	}

}

