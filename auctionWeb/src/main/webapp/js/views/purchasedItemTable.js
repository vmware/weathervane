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
/**
 * View Class for the List Of purchased Items
 * 
 * @author Hal Rosenberg
 */
auction.views.PurchasedItemsTable = Backbone.View
		.extend({

			/**
			 * Bind the events functions to the different HTML elements
			 */
			events : {},

			template : _.template(auction.utils
					.getTemplate(auction.conf.tpls.purchasedItemTable)),

			initialize : function(options) {
				auction.containers.purchasedItemTable = this.$el;
				this.collection.on('sync', this.render, this);
			},

			/**
			 * Renders the Purchased Item table View
			 * 
			 * @author Harold Rosenberg
			 * @return void
			 */
			render : function() {
				'use strict';
				var paginator, page = this.collection.page, pageSize = this.collection.pageSize, totalRecords = this.collection.totalRecords, pageCount = Math
						.ceil(totalRecords / pageSize);

				this.$el.empty();

				if (page > pageCount) {
					page = pageCount;
				}
				paginator = new auction.views.Paginator({
					pageCount : pageCount,
					page : page,
					hash : auction.conf.hash.purchaseHistoryPage,
					interval : auction.utils.getPaginationInterval(page,
							pageCount)
				});

				// If it hasn't been rendered yet, build the section and store
				// the key dom objects
				this.$el.html(this.template());

				// Activate the date pickers
				this.$("#purchasedItemsFromDate").datepicker({
					dateFormat : "mm/dd/yy",
					appendText : "(mm/dd/yyyy)",
					constrainInput : true,
					autoSize : true,
					changeMonth : true,
					changeYear : true
				});
				this.$("#purchasedItemsToDate").datepicker({
					dateFormat : "mm/dd/yy",
					appendText : "(mm/dd/yyyy)",
					defaultDate : "02/02/2020",
					constrainInput : true,
					autoSize : true,
					changeMonth : true,
					changeYear : true
				});
				this.$("#purchaseHistorySearch").click(function(ev) {
					auction.instances.purchasedItemsView.purchaseHistorySearch();
				});

				// Embed the paginator into the container
				this.$el.find('.pagination-container').html(paginator.render());
				this.tbody = this.$el.find('#purchasedItemTableBody'); 
				this.paginationControl = this.$('.pagination-container');

				// Check the page count of orders
				if (pageCount > 0) {
					// Render the list of orders
					this.collection.forEach(this.addOne, this);
				}

				return this;
			},

			/**
			 * Adds a single auction model into the view
			 * 
			 * @author Hal Rosenberg
			 * @return void
			 */
			addOne : function(tableRow) {
				var purchaseDate = new Date(tableRow.get("biddingEndTime"));
				tableRow.set({biddingEndTime: purchaseDate.toDateString()});
				var itemRowView = new auction.views.PurchasedItemRow({
					model : tableRow
				});
				this.tbody.append(itemRowView.render().el);
			},

			purchaseHistorySearch : function() {
				var fromDate = $("#purchasedItemsFromDate").datepicker("getDate");
				var toDate = $("#purchasedItemsToDate").datepicker("getDate");

				if (fromDate != null) {
					if (toDate != null) {
						auction.instances.purchasedItemsCollection.fetch({
							data : {
								page : 0,
								pageSize : auction.conf.pageSize,
								fromDate : fromDate,
								toDate : toDate
							}
						});
					} else {
						auction.instances.purchasedItemsCollection.fetch({
							data : {
								page : 0,
								pageSize : auction.conf.pageSize,
								fromDate : fromDate
							}
						});
					}
				} else if (toDate != null) {
					auction.instances.purchasedItemsCollection.fetch({
						data : {
							page : 0,
							pageSize : auction.conf.pageSize,
							toDate : toDate
						}
					});
				} else {
					auction.instances.purchasedItemsCollection.fetch({
						data : {
							page : 0,
							pageSize : auction.conf.pageSize
						}
					});
				}

			}

		});
