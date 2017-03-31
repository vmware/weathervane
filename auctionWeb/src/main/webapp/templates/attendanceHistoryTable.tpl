	<div class="title"><h4><%= translate("attendanceHistory") %></h4></div>
	<div id="attendanceHistoryTableDiv">
	<div class="row">
		<div class="col-lg-2"><h5>Change search:</h5></div>
		<div class="col-lg-4">
			<label for="attendanceHistoryFromDate"><%= translate("from") %>:</label> <input
				id="attendanceHistoryFromDate" type="text"
				data-date-format="mm/dd/yyyy" class="datepicker">
		</div>
		<div class="col-lg-4">
			<label for="attendanceHistoryToDate"><%= translate("to") %>:</label> <input
				id="attendanceHistoryToDate" type="text"
				data-date-format="mm/dd/yyyy" class="datepicker">
		</div>
		<div class="col-lg-2">
			<button id="attendanceHistorySearch" type="submit">Search</button>
		</div>
	</div>
	<table id="attendanceHistoryTable" class="table table-striped table-bordered table-condensed well show-well">
		<thead>
        	<tr>
           		<th><%= translate("attendanceDate") %></th>
                <th><%= translate("auctionName") %></th>
               	<th><%= translate("attendanceAction") %></th>
			</tr>
		</thead>
       	<tbody id="attendanceHistoryTableBody"></tbody>
	</table>
    <div class="pagination-container"/>
	</div>
