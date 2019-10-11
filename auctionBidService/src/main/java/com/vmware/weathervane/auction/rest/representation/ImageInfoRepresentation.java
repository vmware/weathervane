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
package com.vmware.weathervane.auction.rest.representation;

import java.io.Serializable;
import java.util.HashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;

public class ImageInfoRepresentation extends Representation implements Serializable {

	private static final long serialVersionUID = 1L;

	private static final Logger logger = LoggerFactory.getLogger(ImageInfoRepresentation.class);

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

		String urlPath = "item/" + Long.toString(theImageInfo.getKey().getEntityid())
							+ "/image/" + theImageInfo.getKey().getImageId().toString();
		if (cacheable) {
			urlPath = urlPath + "/cacheable";
		}
		
		/*
		 *  Create the REST url that the application will understand.
		 */
		// Link for READ image
		itemImageLinks.put(RestAction.READ, urlPath);

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
