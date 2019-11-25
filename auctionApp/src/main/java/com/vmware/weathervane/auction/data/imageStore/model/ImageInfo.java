/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.imageStore.model;

import java.io.Serializable;
import java.util.Date;
import java.util.Objects;
import java.util.UUID;

import org.springframework.cassandra.core.PrimaryKeyType;
import org.springframework.data.cassandra.mapping.PrimaryKey;
import org.springframework.data.cassandra.mapping.PrimaryKeyClass;
import org.springframework.data.cassandra.mapping.PrimaryKeyColumn;
import org.springframework.data.cassandra.mapping.Table;

@Table("image_info")
public class ImageInfo implements Serializable {

	private static final long serialVersionUID = 1L;
	
	@PrimaryKeyClass
	public static class ImageInfoKey implements Serializable {

		private static final long serialVersionUID = 1L;

		@PrimaryKeyColumn(name="entity_id", ordinal= 0, type=PrimaryKeyType.PARTITIONED)
		private Long entityid;

		@PrimaryKeyColumn(name="image_id", ordinal= 1, type=PrimaryKeyType.CLUSTERED)
		private UUID imageId;

		public Long getEntityid() {
			return entityid;
		}

		public void setEntityid(Long entityid) {
			this.entityid = entityid;
		}

		public UUID getImageId() {
			return imageId;
		}

		public void setImageId(UUID imageId) {
			this.imageId = imageId;
		}

		@Override
		public int hashCode() {
			return Objects.hash(entityid, imageId);
		}

		@Override
		public boolean equals(Object obj) {
			if (this == obj)
				return true;
			if (obj == null)
				return false;
			if (getClass() != obj.getClass())
				return false;
			ImageInfoKey other = (ImageInfoKey) obj;
			return Objects.equals(entityid, other.entityid) 
					&& Objects.equals(imageId, other.imageId);
		}
	}
	
	@PrimaryKey
	private ImageInfoKey key;
	
	/*
	 * The field is used by the Weathervane benchmark infrastructure to 
	 * simplify cleanup between runs.
	 */
	private boolean preloaded;

	private String name;
	private String format;
	
	private Long imagenum = 0L;
	
	private Date dateadded;
	
	
	public ImageInfo() {
		
	}
	
	public ImageInfo(ImageInfo that) {
		this.key = new ImageInfoKey();
		this.key.entityid = that.key.entityid;
		this.preloaded = that.preloaded;
		this.name = that.name;
		this.format = that.format;
		this.imagenum = that.imagenum;
		this.dateadded = that.dateadded;
	}
	
	public ImageInfoKey getKey() {
		return key;
	}

	public void setKey(ImageInfoKey key) {
		this.key = key;
	}

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public String getFormat() {
		return format;
	}

	public void setFormat(String format) {
		this.format = format;
	}

	public Long getImagenum() {
		return imagenum;
	}

	public void setImagenum(Long imagenum) {
		this.imagenum = imagenum;
	}

	public Date getDateadded() {
		return dateadded;
	}

	public void setDateadded(Date dateadded) {
		this.dateadded = dateadded;
	}
	
	public boolean isPreloaded() {
		return preloaded;
	}

	public void setPreloaded(boolean preloaded) {
		this.preloaded = preloaded;
	}
}
