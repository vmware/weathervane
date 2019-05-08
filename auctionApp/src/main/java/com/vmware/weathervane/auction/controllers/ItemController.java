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
import java.io.PrintWriter;
import java.util.Collection;
import java.util.Date;
import java.util.Enumeration;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.UUID;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.Part;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.multipart.MultipartHttpServletRequest;

import com.vmware.weathervane.auction.data.imageStore.ImageQueueFullException;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade.ImageSize;
import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.model.User;
import com.vmware.weathervane.auction.rest.representation.AuctionRepresentation;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.rest.representation.ImageInfoRepresentation;
import com.vmware.weathervane.auction.rest.representation.ItemRepresentation;
import com.vmware.weathervane.auction.service.CacheWarmerService;
import com.vmware.weathervane.auction.service.ItemService;
import com.vmware.weathervane.auction.service.exception.AuctionNotActiveException;
import com.vmware.weathervane.auction.service.liveAuction.LiveAuctionService;

@Controller
@RequestMapping(value = "/item")
public class ItemController extends BaseController {
	private static final Logger logger = LoggerFactory.getLogger(ItemController.class);

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
		double thumbnailMissRate = itemService.getThumbnailMisses() / (double) thumbnailGets;
		double previewMissRate = itemService.getPreviewMisses() / (double) previewGets;
		double fullMissRate = itemService.getFullMisses() / (double) fullGets;
		
		logger.warn("Image Cache Stats: ");
		logger.warn("Thumbnail images.  Gets = " + thumbnailGets + ", misses = " + itemService.getThumbnailMisses() + ", miss rate = " + thumbnailMissRate);
		logger.warn("Preview images.  Gets = " + previewGets + ", misses = " + itemService.getPreviewMisses() + ", miss rate = " + previewMissRate);
		logger.warn("Full images.  Gets = " + fullGets + ", misses = " + itemService.getFullMisses() + ", miss rate = " + fullMissRate);
	}

	@Inject
	@Named("liveAuctionService")
	private LiveAuctionService liveAuctionService;

	private ItemService itemService;

	@Inject
	@Named("itemService")
	public void setItemService(ItemService itemService) {
		this.itemService = itemService;
	}

	@RequestMapping(value = "/{itemId}", method = RequestMethod.GET)
	public @ResponseBody
	ItemRepresentation getItem(@PathVariable long itemId) {
		ItemRepresentation theItem;
		String username = this.getSecurityUtil().getUsernameFromPrincipal();

		logger.info("ItemController::getItem itemId = " + itemId + ", username = " + username);
		theItem = itemService.getItem(itemId);
		return theItem;

	}

	@RequestMapping(value = "/auction/{auctionId}", method = RequestMethod.GET)
	public @ResponseBody
	CollectionRepresentation<ItemRepresentation> getItems(@PathVariable long auctionId,
			@RequestParam(value = "page", required = false) Integer page,
			@RequestParam(value = "pageSize", required = false) Integer pageSize) {
		String username = this.getSecurityUtil().getUsernameFromPrincipal();

		logger.info("LiveAuctionController::getItems auctionId = " + auctionId + ", username = " + username);

		CollectionRepresentation<ItemRepresentation> itemsPage = itemService.getItems(auctionId, page,
				pageSize);
		if (itemsPage.getResults() != null) {
			logger.info("ItemController::getItems.  ItemService returned totalRecords = "
					+ itemsPage.getTotalRecords() + ", numresults = "
					+ itemsPage.getResults().size());
		} else {
			logger.info("ItemController::getItems.  ItemService returned null totalRecords");
		}
		return itemsPage;

	}

	@RequestMapping(value = "/current/auction/{auctionId}", method = RequestMethod.GET)
	public @ResponseBody
	ItemRepresentation getCurrentItem(@PathVariable long auctionId, HttpServletResponse response) {
		String username = this.getSecurityUtil().getUsernameFromPrincipal();

		logger.info("ItemController::getCurrentItem auctionId = " + auctionId + ", username = " + username);

		ItemRepresentation returnItem = null;
		try {
			returnItem = liveAuctionService.getCurrentItem(auctionId);
		} catch (AuctionNotActiveException ex) {
			response.setStatus(HttpServletResponse.SC_GONE);
			response.setContentType("text/html");
			try {
				PrintWriter responseWriter = response.getWriter();
				responseWriter.print("AuctionComplete");
				responseWriter.close();
				return null;
			} catch (IOException e1) {
				logger.warn("ItemController::getCurrentItem: got IOException when writing AuctionComplete message to reponse"
						+ e1.getMessage());
			}
		}
		
		return returnItem;
	}

	@RequestMapping(value = "/auctioneer/{auctioneerId}", method = RequestMethod.GET)
	public @ResponseBody
	CollectionRepresentation<ItemRepresentation> getItemsForAuctioneer(@PathVariable long auctioneerId,
			@RequestParam(value = "page", required = false) Integer page,
			@RequestParam(value = "pageSize", required = false) Integer pageSize,
			HttpServletResponse response) {
		String username = this.getSecurityUtil().getUsernameFromPrincipal();

		logger.info("ItemController::getItemsForAuctioneer auctioneerId = " + auctioneerId + ", username = " + username);

		CollectionRepresentation<ItemRepresentation> itemsPage = itemService.getItemsForAuctioneer(
				auctioneerId, page, pageSize);
		return itemsPage;
	}

	@RequestMapping(value = "/user/{userId}/purchased", method = RequestMethod.GET)
	public @ResponseBody
	CollectionRepresentation<ItemRepresentation> getPurchasedItemsForUser(@PathVariable long userId,
			@RequestParam(value = "page", required = false) Integer page,
			@RequestParam(value = "pageSize", required = false) Integer pageSize,
			@RequestParam(value = "fromDate", required = false) Date fromDate,
			@RequestParam(value = "toDate", required = false) Date toDate,
			HttpServletResponse response) {
		logger.info("ItemController::getPurchasedItemsForUser userId = " + userId);

		// Can only get history for the authenticated user
		try {
			this.getSecurityUtil().checkAccount(userId);
		} catch (AccessDeniedException ex) {
			response.setStatus(HttpServletResponse.SC_FORBIDDEN);
			return null;
		}

		CollectionRepresentation<ItemRepresentation> itemsPage = itemService.getPurchasedItemsForUser(userId,
				fromDate, toDate, page, pageSize);
		return itemsPage;
	}

	@RequestMapping(method = RequestMethod.POST)
	public @ResponseBody
	ItemRepresentation addItem(@RequestBody ItemRepresentation theItem) {
		String username = this.getSecurityUtil().getUsernameFromPrincipal();

		logger.info("ItemController::addItem : " + theItem.toString() + ", username = " + username);
		Long userId = this.getSecurityUtil().getAccountFromPrincipal();

		ItemRepresentation itemRepresentation = null;
		while (itemRepresentation == null) {
			try {
				// Post the new bid
				itemRepresentation = itemService.addItem(theItem, userId);

				logger.info("ItemController itemId=" + itemRepresentation.getId());
			} catch (ObjectOptimisticLockingFailureException ex) {
				logger.info("ItemController: got ObjectOptimisticLockingFailureException with message "
						+ ex.getMessage());
			} catch (CannotAcquireLockException ex) {
				logger.warn("ItemController: got CannotAcquireLockException with message "
						+ ex.getMessage());
			}
		}

		return itemRepresentation;
	}

	@RequestMapping(value = "/{id}", method = RequestMethod.PUT)
	public @ResponseBody
	ItemRepresentation updateItem(@PathVariable long id, @RequestBody ItemRepresentation theItem,
			HttpServletResponse response) {
		String username = this.getSecurityUtil().getUsernameFromPrincipal();

		logger.info("ItemController::updateItem, username = " + username);

		// Only allow an auctioneer to update their items
		User theAuctioneer = itemService.getAuctioneerForItem(theItem);
		try {
			this.getSecurityUtil().checkAccount(theAuctioneer.getId());
		} catch (AccessDeniedException ex) {
			response.setStatus(HttpServletResponse.SC_FORBIDDEN);
			return null;
		}

		Boolean suceeded = false;
		while (!suceeded) {
			try {
				theItem = itemService.updateItem(theItem);
				suceeded = true;
			} catch (ObjectOptimisticLockingFailureException ex) {
				logger.info("UserController::updateUser got ObjectOptimisticLockingFailureException with message "
						+ ex.getMessage());
			} catch (CannotAcquireLockException ex) {
				logger.warn("UserController::updateUser got CannotAcquireLockException with message "
						+ ex.getMessage());
			} 

		}

		return theItem;
	}
	
//	@RequestMapping(value = "/{itemId}/image", method = RequestMethod.POST)
//	public @ResponseBody
//	List<ItemImageRepresentation> addImagesForItemNonMultipart(@PathVariable long itemId, HttpServletRequest request,
//			HttpServletResponse response) throws IllegalStateException, IOException, ServletException {
//		logger.warn("addImagesForItem nonMultipart, itemId = " + itemId + " headers:");
//
//		Enumeration<String> headerNames = request.getHeaderNames();
//		while (headerNames.hasMoreElements()) {
//			String name = headerNames.nextElement();
//			Enumeration<String> headers = request.getHeaders(name);
//			while (headers.hasMoreElements()) {
//				logger.warn("\tnonMultipart: " + name + " : " + headers.nextElement());
//			}
//		}
//		
//		logger.warn("nonMultipart contentType: " + request.getContentType());
//		logger.warn("nonMultipart contentlength: " + request.getContentLength());
//		logger.warn("nonMultipart contextPath: " + request.getContextPath());
//		logger.warn("nonMultipart Method: " + request.getMethod());
//		logger.warn("nonMultipart pathInfo: " + request.getPathInfo());
//				
//		Collection<Part> parts =  request.getParts();
//		logger.warn("nonMultipart number of parts = " + parts.size());
//		int i=1;
//		for (Part part : parts) {
//			logger.warn("nonMultipart part " + i + ", contentType = " + part.getContentType());
//			logger.warn("nonMultipart part " + i + ", name = " + part.getName());
//			logger.warn("nonMultipart part " + i + ", size = " + part.getSize());
//			Collection<String> partHeaderNames = part.getHeaderNames();
//			for (String partHeadername : partHeaderNames) {
//				for (String partHeader : part.getHeaders(partHeadername)) {
//					logger.warn("nonMultipart part " + i + ", headername = " + partHeadername + " value = " + partHeader);
//				}
//			}
//			StringWriter writer = new StringWriter();
//			IOUtils.copy(part.getInputStream(), writer);
//			String partString = writer.toString();
//			logger.warn("nonMultipart part " + i + ", inputstream:");
//			logger.warn(partString);
//		}
//
//		StringWriter writer = new StringWriter();
//		IOUtils.copy(request.getInputStream(), writer);
//		String bodyString = writer.toString();
//		logger.warn("nonMultipart body inputstream:");
//		logger.warn(bodyString);
//		
//		return null;
//	}
		
	@RequestMapping(value = "/{itemId}/image", method = RequestMethod.POST)
	public @ResponseBody
	List<ImageInfoRepresentation> addImagesForItem(@PathVariable long itemId, MultipartHttpServletRequest request,
			HttpServletResponse response) throws IllegalStateException, IOException, ServletException {
		String username = this.getSecurityUtil().getUsernameFromPrincipal();

		logger.info("addImagesForItem, itemId = " + itemId + ", username = " + username + ", Headers: ");
		
		Enumeration<String> headerNames = request.getHeaderNames();
		while (headerNames.hasMoreElements()) {
			String name = headerNames.nextElement();
			Enumeration<String> headers = request.getHeaders(name);
			while (headers.hasMoreElements()) {
				logger.debug("\tMultipart: " + name + " : " + headers.nextElement());
			}
		}

		logger.debug("Multipart contentType: " + request.getContentType());
		logger.debug("Multipart contentlength: " + request.getContentLength());
		logger.debug("Multipart contextPath: " + request.getContextPath());
		logger.debug("Multipart Method: " + request.getMethod());
		logger.debug("Multipart pathInfo: " + request.getPathInfo());
		
		Collection<Part> parts =  request.getParts();
		logger.debug("Multipart number of parts = " + parts.size());
		int i=1;
		for (Part part : parts) {
			logger.debug("Multipart part " + i + ", contentType = " + part.getContentType());
			logger.debug("Multipart part " + i + ", name = " + part.getName());
			logger.debug("Multipart part " + i + ", size = " + part.getSize());
			Collection<String> partHeaderNames = part.getHeaderNames();
			for (String partHeadername : partHeaderNames) {
				for (String partHeader : part.getHeaders(partHeadername)) {
					logger.debug("Multipart part " + i + ", headername = " + partHeadername + " value = " + partHeader);
				}
			}
		}

		// Only allow an auctioneer to update their own items
		User theAuctioneer = itemService.getAuctioneerForItem(itemId);
		try {
			this.getSecurityUtil().checkAccount(theAuctioneer.getId());
		} catch (AccessDeniedException ex) {
			logger.warn("User tried to add image to item it doesn't own");
			response.setStatus(HttpServletResponse.SC_FORBIDDEN);
			return null;
		}
	    
        Iterator<String> itr =  request.getFileNames();
        MultipartFile mpf = null;

        // Make sure that all of the uploaded files are images less than 16MB
        while(itr.hasNext()){

        	mpf = request.getFile(itr.next());
        	
        	if (!mpf.getContentType().startsWith("image")) {
        		logger.error("Uploading an image with wrong contentType");
    			response.sendError(HttpServletResponse.SC_NOT_ACCEPTABLE, "Attempted to upload a file that is not an image");
    			return null;
        	}

        	/*
        	 * Only accept images less than 16MB - 2KB
        	 * The 2KB is to leave room for the rest of the Mongo document 
        	 */
        	if (mpf.getSize() > (16 * 1024 * 1024 - 2048)) {
        		logger.error("Uploading an larger than 16MB = 2KB, size = " + mpf.getSize());
    			response.sendError(HttpServletResponse.SC_NOT_ACCEPTABLE, "Images must be less than 16MB - 2KB");
    			return null;
        	}
        	
        }
        
        List<ImageInfoRepresentation> theImages = new LinkedList<ImageInfoRepresentation>();
        itr =  request.getFileNames();
        while(itr.hasNext()){
        	mpf = request.getFile(itr.next());
        
            logger.debug("name = " + mpf.getName() + ", originalName: " + mpf.getOriginalFilename() +" uploaded! Size =  " + mpf.getSize()/1024 + "KB, type = " + mpf.getContentType());
            
            ImageInfoRepresentation anImage = null;
            try {
            	anImage = itemService.addImageForItem(itemId, mpf.getBytes(), mpf.getOriginalFilename());
            } catch (IOException ex) {
            	logger.error(ex.getMessage());
            } catch (ImageQueueFullException ex) {
    			logger.warn(ex.getMessage());
    			response.setStatus(HttpServletResponse.SC_SERVICE_UNAVAILABLE);
    			return null;
            }
            
            theImages.add(anImage);
        }

		return theImages;
	}
	
	@RequestMapping(value = "/{itemId}/image/{imageId}", method = RequestMethod.GET)
	public HttpEntity<byte[]> getImageForItem(@PathVariable long itemId, @PathVariable UUID imageId,
			@RequestParam(value = "size", required = false) ImageStoreFacade.ImageSize size) throws IOException {
		logger.debug("getImageForItem, itemId = " + itemId + ", imageId = " + imageId + ", size = " + size);

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
			image = itemService.getPreviewImageForItem(itemId, imageId);
		} else if (size == ImageSize.THUMBNAIL) {
			thumbnailGets++;
			image = itemService.getThumbnailImageForItem(itemId, imageId);
		} else {
			fullGets++;
			image = itemService.getFullImageForItem(itemId, imageId);
		}

		HttpHeaders headers = new HttpHeaders();
		headers.setContentType(MediaType.IMAGE_JPEG);
		headers.setContentLength(image.length);
		
		return new HttpEntity<byte[]>(image, headers);
	}

	@RequestMapping(value = "/{itemId}/image/{imageId}/cacheable", method = RequestMethod.GET)
	public HttpEntity<byte[]> getImageForItemCacheable(@PathVariable long itemId, @PathVariable UUID imageId,
			@RequestParam(value = "size", required = false) ImageStoreFacade.ImageSize size) throws IOException {
		logger.debug("getImageForItem, itemId = " + itemId + ", imageId = " + imageId + ", size = " + size);

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
			image = itemService.getPreviewImageForItem(itemId, imageId);
		} else if (size == ImageSize.THUMBNAIL) {
			thumbnailGets++;
			image = itemService.getThumbnailImageForItemCacheable(itemId, imageId);
		} else {
			fullGets++;
			image = itemService.getFullImageForItem(itemId, imageId);
		}

		HttpHeaders headers = new HttpHeaders();
		headers.setContentType(MediaType.IMAGE_JPEG);
		headers.setContentLength(image.length);
		
		return new HttpEntity<byte[]>(image, headers);
	}

}

