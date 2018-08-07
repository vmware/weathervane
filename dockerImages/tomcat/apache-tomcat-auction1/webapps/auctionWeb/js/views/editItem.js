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
 * View Class for Updating Profile
 * 
 */
auction.views.EditItem = Backbone.View
		.extend({

			/**
			 * Bind the events functions to the different HTML elements
			 */
			events : {
				'click #editItemBtn' : 'edit',
			},

			initialize : function(options) {
				auction.containers.editItem = this.$el;
				this.model.on('sync', this.render, this);
			},

			/**
			 * Renders the Update profile view
			 */
			render : function() {

				var originDate = new Date(this.model.get("dateOfOrigin"));
				var originDateString = originDate.toDateString();
				this.model.set({ dateOfOriginString: originDateString});
				
				this.$el.html(_.template(auction.utils.getTemplate(auction.conf.tpls.editItem))(this.model.attributes));
				this.$("#editItem-longDescription-input").text(this.model.get("longDescription"));
				this.$("#editItem-condition-input").val(this.model.get("condition"));
				
				// Activate the date picker
				this.$("#editItem-dateOfOrigin-input").datepicker({
					dateFormat : "mm/dd/yy",
					appendText : "(mm/dd/yyyy)",
					constrainInput : true,
					autoSize : true,
					changeMonth : true,
					changeYear : true
				});

				// Activate the fileuploader
				var itemId = this.model.get("id");
				var url =auction.conf.urlRoot + "item/" + itemId + "/image" ;
								
				var uploadButton = $('<button/>').addClass('btn btn-primary').prop('disabled', true).text(
						'Processing...').on('click', function() {
							var $this = $(this), 
							data = $this.data();
							$this.off('click').text('Abort').on('click', function() {
								$this.remove();
								data.abort();
							});
							data.submit().always(function() {
								$this.remove();
								$this.preventDefault();
							});
						});
				
				$('#editItem-addImage-input')
						.fileupload({
							url : url,
							headers: { API_TOKEN : auction.session.authToken },
							dataType : 'json',
							autoUpload : false,
							acceptFileTypes : /(\.|\/)(gif|jpe?g|png)$/i,
							// Enable image resizing, except for Android and
							// Opera,
							// which actually support image resizing, but fail
							// to
							// send Blob objects via XHR requests:
							disableImageResize : /Android(?!.*Chrome)|Opera/.test(window.navigator.userAgent),
							previewMaxWidth : 100,
							previewMaxHeight : 100,
							previewCrop : true
						})
						.on('fileuploadadd', function(e, data) {
							data.context = $('<div/>').appendTo('#editItem-files');
							$.each(data.files, function(index, file) {
								var node = $('<p/>').append($('<span/>').text(file.name));
								if (!index) {
									node.append('<br>').append(uploadButton.clone(true).data(data));
								}
								node.appendTo(data.context);
							});
						})
						.on(
								'fileuploadprocessalways',
								function(e, data) {
									var index = data.index, file = data.files[index], node = $(data.context
											.children()[index]);
									if (file.preview) {
										node.prepend('<br>').prepend(file.preview);
									}
									if (file.error) {
										node.append('<br>').append(file.error);
									}
									if (index + 1 === data.files.length) {
										data.context.find('button').text('Upload').prop('disabled', !!data.files.error);
									}
								}).on('fileuploadprogressall', function(e, data) {
							var progress = parseInt(data.loaded / data.total * 100, 10);
							$('#editItem-progress .progress-bar').css('width', progress + '%');
						}).on('fileuploaddone', function(e, data) {
							$.each(data.result.files, function(index, file) {
								var link = $('<a>').attr('target', '_blank').prop('href', file.url);
								$(data.context.children()[index]).wrap(link);
							});
						}).on('fileuploadfail', function(e, data) {
							$.each(data.result.files, function(index, file) {
								var error = $('<span/>').text(file.error);
								$(data.context.children()[index]).append('<br>').append(error);
							});
						}).prop('disabled', !$.support.fileInput).parent().addClass(
								$.support.fileInput ? undefined : 'disabled');

				this.$el.show();
			},

			edit : function(event) {

				event.preventDefault();

				var name = this.$('#editItem-name-input').val();
				var manufacturer = this.$('#editItem-manufacturer-input').val();
				var longDescription = this.$('#editItem-longDescription-input').val();
				var startingBid = this.$('#editItem-startingBid-input').val();
				var condition = this.$('#editItem-condition-input').val();
				var dateOfOrigin = this.$("#editItem-dateOfOrigin-input").datepicker("getDate");

				var view = this;

				// Update callbacks
				var callbacks = {
					success : function(model) {
						$("#editItem").html("");
						auction.instances.router.navigate(auction.conf.hash.editItem, true);
					},
					error : function(model, error) {
					}
				};

				this.model.unset("dateOfOriginString", {silent: true});
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