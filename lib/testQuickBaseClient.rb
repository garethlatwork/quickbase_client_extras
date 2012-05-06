
require 'QuickBaseClient'

#  This does not modify any existing databases.
#  If the method throws an exception, you may have one or two unwanted databases
#  in your list of databases in www.quickbase.com.
def testQuickBaseClient( username,
                         password,
                         appname,
                         showGrantedDBs = false,
                         showChildDBs = true,
                         cloneappnameDB = true,
                         createTempDB = true,
                         showTrace = false )

   include QuickBase

   begin

      qbClient = Client.new( username, password, # sign in to QuickBase as username, password
           appname, # open a DB using its name
           true, # use SSL (default)
           true, # show requests sent to QuickBase and reponses returned
           true, # throw an exception back here on the first error
           showTrace # show entire program trace
         )

      if showGrantedDBs
         # list the accessible databases for this user
         qbClient.grantedDBs() { | database| qbClient.printChildElements( database ) }
      end

      appdbid = qbClient.dbid
      qbClient.getDBInfo( appdbid )   # get description etc. of appname
      qbClient.getSchema( appdbid ) # get the schema for appname
      qbClient.doQuery( appdbid )  { |record| qbClient.printChildElements( record ) }   # print all records

      if showChildDBs and qbClient.chdbids         # if appname has child tables
         qbClient.chdbids.each { |chdbid|           # for each child table -
            chdbid = chdbid.text
            qbClient.getDBInfo( chdbid )                #  - get description etc.
            qbClient.getSchema( chdbid )              #  - get schema
            qbClient.doQuery( chdbid ) { |record| qbClient.printChildElements( record ) } # print all records
         }
      end

      if cloneappnameDB
         # make a copy of the database, with the structure but none of the data
         newdbname = newdbdesc = "#{username}'s temporary copy of #{appname} - OK to delete)"
         newdbid = qbClient.cloneDatabase( appdbid, newdbname, newdbdesc, false )

         # delete the copy of the database
         qbClient.deleteDatabase( newdbid )
      end

      if createTempDB
         # make a new database ----------------------------------------
         newdbid = qbClient.createDatabase( "#{username}'s test database.", "This is test database created using a ruby script that calls the QuickBase HTTP API." )

         # add a text field to the new database
         textfid, textlabel = qbClient.addField( newdbid, "text field", "text" )

         # add a file attachment field to the new database
         filefid, filelabel = qbClient.addField( newdbid, "file attachment field", "file" )

         # add a choice field to the new database, with some default choices
         choicefid, choicelabel = qbClient.addField( newdbid, "choice field", "text" )
         qbClient.fieldAddChoices( newdbid, choicefid, %w{ one two three four five } )

         # remove a choice field
         if qbClient.numadded == "5"
            qbClient.fieldRemoveChoices( newdbid, choicefid, "three" )
         end

         # add a record to the new database
         qbClient.addFieldValuePair( nil, textfid, nil, "#{textfid}" )
         qbClient.addFieldValuePair( nil, filefid, "aFile.txt", "Contents of aFile.txt" )
         fvlist = qbClient.addFieldValuePair( nil, choicefid, nil, "four" )
         rid, update_id = qbClient.addRecord( newdbid, fvlist )
         qbClient.getRecordInfo( newdbid, rid ) { |field| qbClient.printChildElements( field ) }

         # edit the record
         qbClient.clearFieldValuePairList
         fvlist = qbClient.addFieldValuePair( nil, choicefid, nil, "two" )
         qbClient.editRecord( newdbid, rid, fvlist )
         qbClient.getRecordInfo( newdbid, rid ) { |field| qbClient.printChildElements( field ) }

         # pass some user data through the API
         myData = "about to call changeRecordOwner"
         qbClient.udata = myData

         # change record owner
         qbClient.changeRecordOwner( newdbid, rid, username )

         # this will throw an exception if udata wasn't in the response
         qbClient.udata = nil if qbClient.udata == myData

         # turn off permission to save views
         qbClient.changePermission( newdbid, username, "any", "any", "true", "true", "false", "true" )

         # get an HTML view of the record
         html = qbClient.getRecordAsHTML( newdbid, rid )
         p html

         # download aFile.txt
         qbClient.downLoadFile( newdbid, rid, filefid )

         # delete 2 fields
         qbClient.deleteField( newdbid, textfid )
         qbClient.deleteField( newdbid, filefid )

         # get a CSV view of the database
         csv = qbClient.genResultsTable( newdbid, nil, nil, nil, nil, nil, "csv" )
         p csv

         # get an HTML form for adding records
         html = qbClient.genAddRecordForm( newdbid )
         p html

         # add an HTML page to the database
         testpage = "<HTML><HEAD><TITLE>test page</TITLE></HEAD><BODY>this is a test page</BODY></HTML>"
         qbClient.addReplaceDBPage( newdbid, nil, "test page", "1",  testpage )

         # get the Default Overview page
         qbClient.getDBPage( newdbid, nil, "Default Overview" )

         # change the label of the choice field
         qbClient.setFieldProperties( newdbid, { "label" => "The only field in this database!" }, choicefid )

         # import some records from CSV
         csvToImport = qbClient.formatImportCSV( "five\r\none\r\nfour" )
         qbClient.importFromCSV( newdbid, csvToImport, choicefid, "1" )

         # print various query results
         qbClient.doQuery( newdbid )
         qbClient.printChildElements( [ qbClient.chdbids, qbClient.queries , qbClient.records, qbClient.fields, qbClient.variables ] )

         # remove records and database
         p qbClient.getNumRecords( newdbid )
         qbClient.purgeRecords( newdbid )
         p qbClient.getNumRecords( newdbid )
         qbClient.deleteDatabase( newdbid )

      end

   rescue StandardError => exception
      puts "#{exception}"
   ensure
      qbClient.signOut # sign out of QuickBase
   end
end

if ARGV[2]
   dbname = ARGV[2]
   (3..ARGV.length-1).each{|i| dbname << " #{ARGV[i]}"}
   testQuickBaseClient( ARGV[0], ARGV[1], dbname )
else
  puts "\nusage: ruby testQuickBaseClient.rb username password application_name"
  puts "\nThis is an old test routine that should still work on www.quickbase.com.\n"
end
