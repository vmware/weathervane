
<div>
	<form class="form-horizontal">
		<fieldset>
			<h4>
				<%= translate("updateProfile") %>
			</h4>
			<div class="row">
				<div class="col-lg-6">
					<div id="updateProfile-firstname-control" class="form-group">
						<label for="updateProfile-firstname-input" class="col-lg-4 control-label"><%=
							translate("firstName") %>:</label>
						<div class="col-lg-8">
							<input type="text" value="<%= firstname %>" id="updateProfile-firstname-input"
								class="form-control pull-right focused"><br /> 
						</div>
					</div>
					<div id="updateProfile-lastname-control" class="form-group">
						<label for="updateProfile-lastname-input" class="col-lg-4 control-label"><%=
							translate("lastName") %>:</label>
						<div class="col-lg-8">
							<input type="text" value="<%= lastname %>" id="updateProfile-lastname-input"
								class="form-control pull-right focused"><br /> 
						</div>
					</div>
					<div id="updateProfile-email-control" class="form-group">
						<label for="updateProfile-email-input" class="col-lg-4 control-label"><%= translate("email") %>:</label>
						<div class="col-lg-8">
							<input type="text" value="<%= username %>" id="updateProfile-email-input"
								class="form-control pull-right focused"><br /> <span id="updateProfile-emailError"
								class="help-inline hide"><%= translate("existingEmailError") %></span>
						</div>
					</div>
					<div id="updateProfile-creditLimit-control" class="form-group">
						<label for="updateProfile-creditLimit-input" class="col-lg-4 control-label"><%= translate("creditLimit") %>:</label>
						<div class="col-lg-8">
							<input type="number" value="<%= creditLimit %>" id="updateProfile-creditLimit-input"
								class="form-control pull-right focused"><br /> <span
								id="updateProfile-creditLimitError" class="help-inline hide"><%=
								translate("creditLimitError") %></span>
						</div>
					</div>
				</div>
				<div class="col-lg-6">
					<div id="updateProfile-password-control" class="form-group">
						<label for="updateProfile-password-input" class="col-lg-4 control-label"><%= translate("password") %>:</label>
						<div class="col-lg-8">
							<input type="password" id="updateProfile-password-input"
								class="form-control pull-right focused"><br /> <span
								id="updateProfile-passwdError" class="help-inline hide"><%=
								translate("passwdError") %></span>
						</div>
					</div>
					<div id="updateProfile-matchpasswd-control" class="form-group">
						<label for="updateProfile-matchpasswd-input" class="col-lg-4 control-label"><%=
							translate("passwordConfirmation") %>:</label>
						<div class="col-lg-8">
							<input type="password" id="updateProfile-matchpasswd-input"
								class="form-control pull-right focused"><br /> <span
								id="updateProfile-matchpasswd-error" class="help-inline hide"><%=
								translate("passwordMatching") %></span>
						</div>
					</div>
				</div>
			</div>
			<div class="row">
				<div class="form-actions offset4 col-lg-4">
					<button id="updateProfileBtn" class="btn green-btn"><%=
						translate("update") %></button>
				</div>
			</div>
		</fieldset>
	</form>
</div>
