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
auction.views.AddItem = Backbone.View
		.extend({

			/**
			 * Bind the events functions to the different HTML elements
			 */
			events : {
				'click #addItemBtn' : 'add',
			},

			initialize : function(options) {
				auction.containers.addItem = this.$el;
			},

			/**
			 * Renders the Update profile view
			 */
			render : function() {

				this.$el.html(_.template(auction.utils.getTemplate(auction.conf.tpls.addItem))());

				// Activate the date picker
				this.$("#addItem-dateOfOrigin-input").datepicker({
					dateFormat : "mm/dd/yy",
					appendText : "(mm/dd/yyyy)",
					constrainInput : true,
					autoSize : true,
					changeMonth : true,
					changeYear : true
				});

				this.$el.show();
			},

			add : function(event) {

				event.preventDefault();

				var name = this.$('#addItem-name-input').val();
				var manufacturer = this.$('#addItem-manufacturer-input').val();
				var longDescription = this.$('#addItem-longDescription-input').val();
				var startingBid = this.$('#addItem-startingBid-input').val();
				var condition = this.$('#addItem-condition-input').val();
				var dateOfOrigin = this.$("#addItem-dateOfOrigin-input").datepicker("getDate");

				var view = this;

				// Update callbacks
				var callbacks = {
					success : function(model) {
						$("#addItem").html("");
						auction.instances.router.navigate(auction.conf.hash.editItem, true);
					},
					error : function(model, error) {
					}
				};

				this.model.save({
					name : name,
					manufacturer : manufacturer,
					longDescription : longDescription,
					startingBidAmount : startingBid,
					condition : condition,
					dateOfOrigin : dateOfOrigin
				}, callbacks);

			}
		});