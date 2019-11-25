/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.imageStore.model;

import java.io.Serializable;
import java.nio.ByteBuffer;
import java.util.Objects;
import java.util.UUID;

import org.springframework.cassandra.core.PrimaryKeyType;
import org.springframework.data.cassandra.mapping.PrimaryKey;
import org.springframework.data.cassandra.mapping.PrimaryKeyClass;
import org.springframework.data.cassandra.mapping.PrimaryKeyColumn;
import org.springframework.data.cassandra.mapping.Table;

@Table("image_thumbnail")
public class ImageThumbnail implements Serializable {

	private static final long serialVersionUID = 1L;
	
	@PrimaryKeyClass
	public static class ImageThumbnailKey  implements Serializable {

		private static final long serialVersionUID = 1L;
		
		@PrimaryKeyColumn(name="image_id", ordinal= 0, type=PrimaryKeyType.PARTITIONED)
		private UUID imageId;	
	
		public UUID getImageId() {
			return imageId;
		}

		public void setImageId(UUID imageId) {
			this.imageId = imageId;
		}

		@Override
		public int hashCode() {
			return Objects.hash(imageId);
		}

		@Override
		public boolean equals(Object obj) {
			if (this == obj)
				return true;
			if (obj == null)
				return false;
			if (getClass() != obj.getClass())
				return false;
			ImageThumbnailKey other = (ImageThumbnailKey) obj;
			return Objects.equals(imageId, other.imageId);
		}
	}
	
	@PrimaryKey
	private ImageThumbnailKey key;
	
	private ByteBuffer image;

	/*
	 * The field is used by the Weathervane benchmark infrastructure to 
	 * simplify cleanup between runs.
	 */
	private boolean preloaded;

	public ImageThumbnailKey getKey() {
		return key;
	}

	public void setKey(ImageThumbnailKey key) {
		this.key = key;
	}

	public ByteBuffer getImage() {
		return image;
	}

	public void setImage(ByteBuffer image) {
		this.image = image;
	}

	public void setImage(byte[] byteImage) {
		this.image = ByteBuffer.wrap(byteImage);
	}

	public boolean isPreloaded() {
		return preloaded;
	}

	public void setPreloaded(boolean preloaded) {
		this.preloaded = preloaded;
	}
}
