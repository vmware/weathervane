/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.representation;

import java.io.Serializable;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ImageInfoRepresentation extends Representation implements Serializable {

	private static final long serialVersionUID = 1L;

	private static final Logger logger = LoggerFactory.getLogger(ImageInfoRepresentation.class);

	private String id;
	private String name;
	private String format;
	private Long itemId;
	private Long imagenum;

	/*
	 * Only create an itemRepresentation with the constructor that understands
	 * the business rules.
	 */
	public ImageInfoRepresentation() {
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
