<div class="row">
	<div class="col-lg-8">
		<form class="form-horizontal">
			<fieldset>
				<legend><%= translate("pleaseLogin") %></legend>
				<div
					id="login-error"
					class="alert alert-block alert-error fade in"
					style="display: none;">
					<a
						data-dismiss="alert"
						class="close">x</a>
					<h4 class="alert-heading"><%= translate("unknownError") %></h4>
					<p></p>
				</div>
				<div class="form-group">
					<label
						for="username-input"
						class="col-lg-2 control-label"><%= translate("username")
						%></label>
					<div class="col-lg-10">
						<input
							type="text"
							class="form-control"
							id="username-input"
							placeholder="<%= translate("enterUsername") %>">
					</div>
				</div>
				<div class="form-group">
					<label
						for="password-input"
						class="col-lg-2 control-label"><%= translate("password")
						%></label>
					<div class="col-lg-10">
						<input
							type="password"
							class="form-control"
							id="password-input"
							placeholder="<%= translate("enterPassword") %>">
					</div>
				</div>
				<div class="form-group">
					<div class="col-lg-offset-2 col-lg-10">
						<button
							type="submit"
							id="loginBtn"
							class="btn btn-default"><%= translate("login") %></button>
					</div>
				</div>
			</fieldset>
		</form>
	</div>
	<div class="col-lg-2 offset1 columns sidebar">
		<h3><%= translate("registration") %></h3>
		<p><%= translate("dontHaveNanotrader") %></p>
		<p>
			<a id="showRegistrationBtn"><%= translate("createOneNow") %></a>
		</p>
	</div>
</div>
</div>
