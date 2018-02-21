<cfsilent>
	<!--- The testDirectory variable should be the path from the webroot to and including the root directory which contains test components --->
	<cfset testDirectory = "/donordrivecore/tests" />
	<cfdirectory action="list" directory="#expandPath(testDirectory)#" name="files" recurse="true"  />
	<cfset pathSeparator = createObject("java", "java.io.File").separator />
	<!--- Delete any folders before the webroot --->
	<cfloop query="files">
		<cfloop condition="listFirst(files.directory, '\/') NEQ listFirst(testDirectory, '\/')">
			<cfset files.directory[files.currentRow] = listDeleteAt(files.directory, 1, "\/") />
		</cfloop>
	</cfloop>
	<!--- Store the number of folders in the webroot.  This is used to compare against files later on --->
	<cfset rootPathLength = listLen(testDirectory, "\/") + 1 />
	<!--- Reorder the query for when we loop through files --->
	<cfquery dbtype="query" name="files">
		SELECT *, #left(files.directory[1], 1) IS pathSeparator ? "" : "'#pathSeparator#' + "#directory + '#pathSeparator#' + name as fullpath
		FROM files
		ORDER BY fullpath, type, name
	</cfquery>
</cfsilent>
<!DOCTYPE html>
<html lang="en">
	<head>
		<!-- Required meta tags -->
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">

		<!-- Bootstrap CSS -->
		<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.0.0-beta/css/bootstrap.min.css" integrity="sha384-/Y6pD6FV/Vv2HJnA6t+vslU6fwYXjCFtcEpHbNJ0lyAFsXTsjBbfaDjzALeQsN6M" crossorigin="anonymous">
		<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css">

		<style>
			.hidden {
				display: none;
			}
			.indent {
				margin-left: 17px;
			}
			.list-group {
				margin: 20px 0;
			}
			.list-group-item {
				cursor: pointer;
				list-style-type: none;
			}
			.list-group-item:hover {
				text-decoration: underline;
			}
		</style>
	</head>
	<body>
		<div class="container">
			<ul class="list-group">
				<cfset parentArray = [] />
				<cfoutput query="files">
					<cfset filePathLength = listlen(files.fullpath, "\/") />
					<cfif files.type IS "dir" OR filePathLength GT rootPathLength>
						<cfif files.type IS "dir">
							<!--- This is how we know the parent for for each file/subdirectory.  We'll add an index for each level down --->
							<cfset parentArray[filePathLength - rootPathLength + 1] = files.currentRow />
						</cfif>
						<cfset classString = "list-group-item" />
						<cfset classString &= filePathLength GT rootPathLength ? " hidden" : "" />
						<cfset classString &= files.type IS "dir" ? " js-dir" : " js-file" />
						<cfset dataAttributeString = 'data-row="#files.currentRow#"' />
						<cfset dataAttributeString &= filePathLength GT rootPathLength ? " data-parent=#parentArray[filePathLength - rootPathLength]#" : "" />
						<li class="#classString#" #dataAttributeString#>
							<!--- Indent one spot over for each level in the "tree" --->
							<cfloop index="i" to="#filePathLength#" from="#rootPathLength + 1#">
								<span class="indent"></span>
							</cfloop>
							<span class="fa fw #files.type IS 'dir' ? 'fa-folder' : 'fa-file-code-o'#"></span>
							#files.name#
							<cfif right(files.name, 3) IS "cfc">
								<a href="//#cgi.SERVER_NAME##files.fullpath#?method=runtestremote&output=html&debug=true" target="_blank" class="pull-right">
									<span class="fa fa-refresh"></span>&nbsp;Run all test methods
								</a>
							</cfif>
						</li>
						<cfif right(files.name, 3) IS "cfc">
							<!--- Generate a list of methods and add them to the list so we can pick a specific method to run --->
							<cftry>
								<cfset dotPath = "" />
								<cfloop index="i" list="#files.fullpath#" delimiters="\/">
									<cfset dotPath = listAppend(dotPath, replace(i, ".cfc", ""), ".") />
								</cfloop>
								<cfset metaData = getComponentMetadata(dotPath) />
								<cfscript>
									resultArray = arrayFilter(metaData.functions, function(element) {
											return !listFindNoCase("afterTests,beforeTests,init,setUp,tearDown", element.name);
										})
										.map(function(element) {
												return element.name;
											});
									resultArray.sort("textnocase", "asc");
								</cfscript>
								<cfloop index="a" array="#resultArray#">
									<li class="list-group-item hidden" data-parent="#files.currentRow#">
										<cfloop index="i" to="#filePathLength#" from="#rootPathLength#">
											<span class="indent"></span>
										</cfloop>
										<a href="//#cgi.SERVER_NAME##files.fullpath#?method=runtestremote&output=html&debug=true&testmethod=#a#" target="_blank">
											<span class="fa fa-refresh"></span>&nbsp;#a#
										</a>
									</li>
								</cfloop>

								<cfcatch>
									<!--- If the component can't be compiled it will throw an error --->
									<li class="list-group-item hidden" data-parent="#files.currentRow#">
										Error generating test methods - #cfcatch.message#
									</li>
								</cfcatch>
							</cftry>
						</cfif>
					</cfif>
				</cfoutput>
			</ul>
		</div>

		<script src="https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js"></script>

		<script type="text/javascript">
			$('.js-dir, .js-file').on('click', function() {
				var $children = $('li[data-parent=' + $(this).data('row') + ']');
				$children.toggle();
				if($(this).hasClass('js-dir')) {
					// toggle folder icon for directories
					$(this).find('.fa').toggleClass('fa-folder').toggleClass('fa-folder-open');
				}
				$.each($children, function() {
					if(!$(this).is(':visible') && $('li[data-parent=' + $(this).data('row') + ']').length) {
						hideAllChildren($(this));
					}
				});
			});

			function hideAllChildren($element) {
				if($element.hasClass('js-dir')) {
					// toggle folder icon for directories
					$element.find('.fa').addClass('fa-folder').removeClass('fa-folder-open');
				}
				var $children = $('li[data-parent=' + $element.data('row') + ']');
				$children.hide();
				$.each($children, function() {
					if(!$(this).is(':visible') && $('li[data-parent=' + $(this).data('row') + ']').length) {
						hideAllChildren($(this));
					}
				});
			}
		</script>
	</body>
</html>