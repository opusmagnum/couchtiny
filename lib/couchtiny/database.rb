require 'couchtiny/utils'

module CouchTiny

  # This class represents an instance of a database on a CouchDB server.
  # Note that any exceptions raised will come from the underlying HTTP
  # adapter, and therefore may vary dependent on which adapter is used.

  # TODO: Attachments

  class Database
    include CouchTiny::Utils

    attr_reader :server, :http, :name, :path

    # Create an object to represent this database.
    #   server = CouchTiny::Server.new(:url=>"http://192.0.2.1:5984")
    #   db = CouchTiny::Database.new(server, "dbname")
    def initialize(server, name)
      @server = server
      @http = server.http
      @name = name
      @path = "/#{name.gsub('/','%2F')}"
    end

    def url
      "#{@server.url}#{@path}"
    end

    # Alternative way to instantiate a Database object directly from its URL.
    # However this will create a separate Server instance for each database,
    # and therefore you won't have a shared pool of uuids.
    #
    #   db = CouchTiny::Database.url("http://192.0.2.1:5984/dbname")
    def self.url(url, opt={})
      require 'uri'
      uri = URI.parse(url)
      name = uri.path.sub(/\A\//,'')
      uri.path = ""
      new(Server.new({:url => uri.to_s}.merge(opt)), name)
    end

    # Create the database (will raise 412 if already exists)
    def create_database!
      @http.put(@path)
    end

    # Delete the entire database
    def delete_database!
      @http.delete(@path)
    end

    # Delete the database if it exists and create it
    def recreate_database!
      delete_database! rescue nil
      create_database!
    end

    # Get the database info
    def info
      @http.get(@path)
    end

    # Start compacting the database (use 'info' to monitor progress)
    def compact!
      @http.post("#{@path}/_compact")
    end
    
    # Get a document
    def get(docid, opt={})
      path = "#{@path}/#{escape_docid(docid)}"
      @http.get(paramify_path(path, opt))
    end

    # Save a document. Returns {"ok"=>"true", "id"=>id, "rev"=>rev} but does
    # *not* update the _id or _rev attributes of the doc. This is useful if
    # you wish to save the same doc to multiple databases, possibly in
    # concurrent threads
    def put_noupdate(doc, opt={})
      path = "#{@path}/#{escape_docid(doc['_id'] || @server.next_uuid)}"
      @http.put(paramify_path(path, opt), doc)
    end

    # Save a document and update its attributes
    def put(doc, opt={})
      result = put_noupdate(doc, opt)
      if result['ok']
        doc['_id'] = result['id']
        doc['_rev'] = result['rev']
      end
      result
    end
    
    # Perform a bulk save of an array of docs. Returns the result structure
    # but does *not* update the _id or _rev attributes of each doc
    def bulk_docs_noupdate(docs, opt={})
      path = "#{@path}/_bulk_docs"
      body = {'docs' => docs}
      if opt.has_key?(:all_or_nothing)
        body['all_or_nothing'] = opt.delete(:all_or_nothing)
      end
      @http.post(paramify_path(path, opt), body)
    end

    # Performs a bulk save of an array of docs, and updates the _rev of
    # each one. (We assume that _bulk_docs returns its result array in the
    # same order as the request). You still need to check the response
    # to look for failures.
    def bulk_docs(docs, opt={})
      result = bulk_docs_noupdate(docs, opt)
      if result.is_a?(Array)
        result.each_with_index do |res,i|
          doc = docs[i]
          id = res['id']
          rev = res['rev']
          next unless rev   # e.g. rejected due to conflict
          doc['_id'] ||= id
          doc['_rev'] = rev
        end
      end
      result
    end

    # Delete a single document. You may specify :rev=>"nnn" to override
    # the revision.
    def delete(doc, opt={})
      id = doc['_id']
      rev = opt[:rev] || doc['_rev']
      raise "Both id and rev must be present to delete" unless id && rev
      path = "#{@path}/#{escape_docid(id)}"
      @http.delete(paramify_path(path, opt.merge(:rev=>rev)))
    end

    # Copy document from id1 to id2. If document with id2 already exists,
    # you need to pass rev2 as well.
    def copy(id1, id2, rev2=nil)
      src_path = "#{@path}/#{escape_docid(id1)}"
      dst = escape_docid(id2)
      if rev2
        dst = paramify_path(dst, :rev=>rev2)
      end
      @http.copy(src_path, dst)
    end
        
    # Return all docs in the database, or selected docs by passing :keys param
    def all_docs(opt={}, &blk) #:yields: row
      fetch_view("#{@path}/_all_docs", opt, &blk)
    end

    # Return a view
    def view(name, opt={}, &blk) #:yields: row
      design, vname = name.split('/', 2)
      fetch_view("#{@path}/_design/#{design}/_view/#{escape(vname)}", opt, &blk)
    end

    # Return a temporary (aka slow) view
    #
    #   db.temp_view({:map=>"..."}, {:include_docs=>true})
    #   db.temp_view({:map=>"...", :reduce=>"..."}, {:startkey=>x, :endkey=>y})
    def temp_view(funcs, opt={}, &blk) #:yields: row
      body = {}
      funcs.each { |k,v| body[k.to_s] = v }
      fetch_view("#{@path}/_temp_view", opt, body, &blk)
    end

  private
    def fetch_view(path, opt, body=nil, &blk)
      if (keys = opt.delete(:keys))
        body ||= {}
        body['keys'] = keys
      end
      path = paramify_path(path, opt)
      
      if block_given?
        @http.stream(path, body, &blk)
      elsif body
        @http.post(path, body)
      else
        @http.get(path)
      end
    end

    # Utility function: add query part to path
    def paramify_path(path, params = {})
      if params && !params.empty?
        query = params.collect do |k,v|
          v = @http.unparse(v) if %w{key startkey endkey}.include?(k.to_s)
          "#{k}=#{escape(v.to_s)}"
        end.join("&")
        path = "#{path}?#{query}"
      end
      path
    end
  end
end
