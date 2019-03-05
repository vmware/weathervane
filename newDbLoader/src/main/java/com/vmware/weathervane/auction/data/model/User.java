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
 package com.vmware.weathervane.auction.data.model;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

import javax.persistence.CascadeType;
import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.EnumType;
import javax.persistence.Enumerated;
import javax.persistence.FetchType;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.OneToMany;
import javax.persistence.Table;
import javax.persistence.Version;

@Entity
@Table(name = "userdata")
//@Cacheable
//@Cache(usage=CacheConcurrencyStrategy.READ_WRITE)
public class User implements Serializable, DomainObject {

	private static final long serialVersionUID = 1L;

	public enum UserState {
		REGISTERED, INCOMPLETE, DUPLICATE, NOPASSWORD
	};

	private Long id;
	private UserState state;

	// The email address is used as the username.
	// It must be unique.
	private String email;

	private String firstname;
	private String lastname;

	private String authToken;
	
	// Eventually replace this with paymentMethod
	private Float creditLimit;

	// Fields related to security
	private String password; // stored as SHA1 hash
	private boolean enabled;
	private boolean loggedin;
	private String authorities;

	// References to other entities
	private List<Auction> auctions = new ArrayList<Auction>();

	Integer version;

	public User() {
	}

	@Id
	@GeneratedValue(strategy=GenerationType.TABLE)
	public Long getId() {
		return id;
	}

	public void setId(Long id) {
		this.id = id;
	}

	@Enumerated(EnumType.STRING)
	public UserState getState() {
		return state;
	}

	public void setState(UserState state) {
		this.state = state;
	}

	public String getEmail() {
		return email;
	}

	public void setEmail(String email) {
		this.email = email;
	}

	public String getPassword() {
		return password;
	}

	public void setPassword(String password) {
		// this.password = getHash(password, null);
		this.password = password;
	}

	public boolean isEnabled() {
		return enabled;
	}

	public void setEnabled(boolean enabled) {
		this.enabled = enabled;
	}

	public String getAuthorities() {
		return authorities;
	}

	public void setAuthorities(String authorities) {
		this.authorities = authorities;
	}

	public String getFirstname() {
		return firstname;
	}

	public void setFirstname(String firstname) {
		this.firstname = firstname;
	}

	public String getLastname() {
		return lastname;
	}

	public void setLastname(String lastname) {
		this.lastname = lastname;
	}

	@Column(name = "authtoken")
	public String getAuthToken() {
		return authToken;
	}

	public void setAuthToken(String authToken) {
		this.authToken = authToken;
	}

	@Column(name = "creditlimit")
	public Float getCreditLimit() {
		return creditLimit;
	}

	public void setCreditLimit(Float creditLimit) {
		this.creditLimit = creditLimit;
	}
	
	@OneToMany(mappedBy = "auctioneer", cascade = { javax.persistence.CascadeType.PERSIST, CascadeType.REFRESH,
			CascadeType.MERGE }, fetch=FetchType.LAZY)
	public List<Auction> getAuctions() {
		return auctions;
	}

	private void setAuctions(List<Auction> auctions) {
		this.auctions = auctions;
	}

	public void addAuction(Auction auction) {
		this.auctions.add(auction);
		auction.setAuctioneer(this);
	}

	@Version
	public Integer getVersion() {
		return version;
	}

	private void setVersion(Integer version) {
		this.version = version;
	}

	public boolean isLoggedin() {
		return loggedin;
	}

	public void setLoggedin(boolean loggedin) {
		this.loggedin = loggedin;
	}

	@Override
	public boolean equals(Object that) {
		if (that == null) return false;
		User thatUser = (User) that;
		if (this.email.equals(thatUser.email)) {		
			return true;
		} else {
			return false;
		}
	}
	
	@Override
	public String toString() {
		return "firstName: " + this.getFirstname() + " lastName: " + this.getLastname() + " email: " + this.getEmail();
	}

}
