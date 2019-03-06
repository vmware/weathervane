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
package com.vmware.weathervane.auction.data.imageStore.model;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

import org.springframework.cassandra.core.Ordering;
import org.springframework.cassandra.core.PrimaryKeyType;
import org.springframework.data.cassandra.mapping.PrimaryKey;
import org.springframework.data.cassandra.mapping.PrimaryKeyClass;
import org.springframework.data.cassandra.mapping.PrimaryKeyColumn;
import org.springframework.data.cassandra.mapping.Table;

@Table("image_full")
public class ImageFull implements Serializable {

	private static final long serialVersionUID = 1L;
	
	@PrimaryKeyClass
	public static class ImageFullKey  implements Serializable {

		private static final long serialVersionUID = 1L;

		@PrimaryKeyColumn(name="image_id", ordinal= 0, type=PrimaryKeyType.PARTITIONED)
		private UUID imageId;	

		/*
		 * The field is used by the Weathervane benchmark infrastructure to 
		 * simplify cleanup between runs.
		 */
		@PrimaryKeyColumn(name="preloaded", ordinal= 1, type=PrimaryKeyType.CLUSTERED, ordering=Ordering.DESCENDING)
		private boolean preloaded;
	
		public UUID getImageId() {
			return imageId;
		}

		public void setImageId(UUID imageId) {
			this.imageId = imageId;
		}

		public boolean isPreloaded() {
			return preloaded;
		}

		public void setPreloaded(boolean preloaded) {
			this.preloaded = preloaded;
		}

		@Override
		public int hashCode() {
			return Objects.hash(imageId, preloaded);
		}

		@Override
		public boolean equals(Object obj) {
			if (this == obj)
				return true;
			if (obj == null)
				return false;
			if (getClass() != obj.getClass())
				return false;
			ImageFullKey other = (ImageFullKey) obj;
			return Objects.equals(imageId, other.imageId) && preloaded == other.preloaded;
		}
	}
	
	@PrimaryKey
	private ImageFullKey key;
	
	private byte[] image;

	public ImageFullKey getKey() {
		return key;
	}

	public void setKey(ImageFullKey key) {
		this.key = key;
	}

	public byte[] getImage() {
		return image;
	}

	public void setImage(byte[] image) {
		this.image = image;
	}
}
