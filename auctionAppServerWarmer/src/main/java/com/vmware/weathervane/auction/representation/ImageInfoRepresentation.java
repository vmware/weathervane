/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.representation;

import java.io.Serializable;
import java.util.HashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.auction.imageStore.model.ImageInfo;

public class ImageInfoRepresentation extends Representation implements Serializable {

	private static final long serialVersionUID = 1L;

	private static final Logger logger = LoggerFactory.getLogger(ImageInfoRepresentation.class);

	private static String ReadItemImagePath = "item/{itemId}/image/{imageId}";
	private static String ReadItemImageCacheablePath = "item/{itemId}/image/{imageId}/cacheable";

	private String id;
	private String name;
	private String format;
	private Long itemId;
	private Long imagenum;

	/**
	 * This constructor creates an itemImageRepresentation from an ItemImage. It
	 * uses the business rules to determine what the allowable next actions are
	 * based on the current state of the auction and item. It then includes
	 * appropriate links for those actions in the representation.
	 * 
	 * @author hrosenbe
	 */
	public ImageInfoRepresentation(ImageInfo theImageInfo) {
		ImageInfoRepresentation representation = new ImageInfoRepresentation();

		if (theImageInfo == null) {
			logger.warn("Got null imageInfo");
			return;
		}

		representation.setImagenum(theImageInfo.getImagenum());
		representation.setId(theImageInfo.getKey().getImageId().toString());
		representation.setImageFormat(theImageInfo.getFormat());
		representation.setName(theImageInfo.getName());
		representation.setItemId(theImageInfo.getKey().getEntityid());
	}

	/*
	 * Only create an itemRepresentation with the constructor that understands
	 * the business rules.
	 */
	private ImageInfoRepresentation() {
	}

	public static Map<RestAction, String> createItemImageLinks(ImageInfo theImageInfo, boolean cacheable) {
		logger.debug("createItemImageLinks for itemImage " + theImageInfo.getName());

		Map<RestAction, String> itemImageLinks = new HashMap<Representation.RestAction, String>();

		String urlPath;
		if (cacheable) {
			urlPath = ReadItemImageCacheablePath;
		} else {
			urlPath = ReadItemImagePath;
		}
		
		/*
		 *  Create the REST url that the application will understand.
		 */
		Map<String, String> replacements = new HashMap<String, String>();
		// Link for READ image
		replacements.put("itemId", Long.toString(theImageInfo.getKey().getEntityid()));
		replacements.put("imageId", theImageInfo.getKey().getImageId().toString());
		itemImageLinks.put(RestAction.READ, replaceTokens(urlPath, replacements));

		return itemImageLinks;
	}

	public String getId() {
		return id;
	}

	public void setId(String string) {
		this.id = string;
	}

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public String getImageFormat() {
		return format;
	}

	public void setImageFormat(String imageFormat) {
		this.format = imageFormat;
	}

	public Long getItemId() {
		return itemId;
	}

	public void setItemId(Long itemId) {
		this.itemId = itemId;
	}

	public Long getImagenum() {
		return imagenum;
	}

	public void setImagenum(Long imagenum) {
		this.imagenum = imagenum;
	}

	@Override
	public String toString() {
		String itemString;

		itemString = "Image Id: " + id + "\n" + "Image Name: " + name + "\n" + "Image Format: "
				+ format;

		return itemString;
	}

}
