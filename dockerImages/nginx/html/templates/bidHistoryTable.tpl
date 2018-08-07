	<div class="title"><h4><%= translate("bidHistory") %></h4></div>
	<div id="bidHistoryTableDiv">
	<div class="row">
		<div class="col-lg-2"><h5>Change search:</h5></div>
		<div class="col-lg-4">
			<label for="bidHistoryFromDate"><%= translate("from") %>:</label> <input
				id="bidHistoryFromDate" type="text"
				data-date-format="mm/dd/yyyy" class="datepicker">
		</div>
		<div class="col-lg-4">
			<label for="bidHistoryToDate"><%= translate("to") %>:</label> <input
				id="bidHistoryToDate" type="text"
				data-date-format="mm/dd/yyyy" class="datepicker">
		</div>
		<div class="col-lg-2">
			<button id="bidHistorySearch" type="submit">Search</button>
		</div>
	</div>
	<table id="bidHistoryTable" class="table table-striped table-bordered table-condensed well show-well">
		<thead>
        	<tr>
           		<th><%= translate("bidDate") %></th>
                <th><%= translate("itemDetail") %></th>
               	<th><%= translate("bidAmount") %></th>
               	<th><%= translate("bidMsg") %></th>
			</tr>
		</thead>
       	<tbody id="bidHistoryTableBody"></tbody>
	</table>
    <div class="pagination-container"/>
	</div>
