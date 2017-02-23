require 'ebsco/eds/record'
require 'yaml'

module EBSCO

  module EDS

    # Search Results
    class Results

      # Raw results as Hash
      attr_reader :results
      # Array of EBSCO::EDS::Record results
      attr_reader :records
      # Array of EBSCO::EDS::Record Research Starters
      attr_reader :research_starters
      # Array of EBSCO::EDS::Record Exact Publication Matches
      attr_reader :publication_match

      DBS = YAML::load_file(File.join(__dir__, 'settings.yml'))['databases']

      # Creates search results from the \EDS API search response. It includes information about the results and a list
      # of Record items.
      def initialize(search_results)
  
        @results = search_results

        # convert all results to a list of records
        @records = []
        if stat_total_hits > 0
          @results['SearchResult']['Data']['Records'].each { |record| @records.push(EBSCO::EDS::Record.new(record)) }
        end
  
        # create a special list of research starter records
        @research_starters = []
        _related_records = @results.fetch('SearchResult',{}).fetch('RelatedContent',{}).fetch('RelatedRecords',{})
        if _related_records.count > 0
          _related_records.each do |related_item|
            if related_item['Type'] == 'rs'
              rs_entries = related_item.fetch('Records',{})
              if rs_entries.count > 0
                rs_entries.each do |rs_record|
                  @research_starters.push(EBSCO::EDS::Record.new(rs_record))
                end
              end
            end
          end
        end
  
        # create a special list of exact match publications
        @publication_match = []
        _related_publications = @results.fetch('SearchResult',{}).fetch('RelatedContent',{}).fetch('RelatedPublications',{})
        if _related_publications.count > 0
          _related_publications.each do |related_item|
            if related_item['Type'] == 'emp'
              _publication_matches = related_item.fetch('PublicationRecords',{})
              if _publication_matches.count > 0
                _publication_matches.each do |publication_record|
                  @publication_match.push(EBSCO::EDS::Record.new(publication_record))
                end
              end
            end
          end
        end
  
      end

      # Total number of results found.
      def stat_total_hits
        _hits = @results.fetch('SearchResult',{}).fetch('Statistics',{}).fetch('TotalHits',{})
        _hits == {} ? 0 : _hits
      end

      # Time it took to complete the search in milliseconds.
      def stat_total_time
        @results['SearchResult']['Statistics']['TotalSearchTime']
      end

      # Search criteria used in the search
      # Returns a hash.
      # ==== Example
      #   {
      #      "Queries"=>[{"BooleanOperator"=>"AND", "Term"=>"earthquakes"}],
      #      "SearchMode"=>"all",
      #      "IncludeFacets"=>"y",
      #      "Expanders"=>["fulltext", "thesaurus", "relatedsubjects"],
      #      "Sort"=>"relevance",
      #      "RelatedContent"=>["rs"],
      #      "AutoSuggest"=>"n"
      #    }
      def search_criteria
        @results['SearchRequest']['SearchCriteria']
      end

      # Search criteria actions applied.
      # Returns a hash.
      # ==== Example
      #   {
      #      "QueriesWithAction"=>[{"Query"=>{"BooleanOperator"=>"AND", "Term"=>"earthquakes"}, "RemoveAction"=>"removequery(1)"}],
      #      "ExpandersWithAction"=>[{"Id"=>"fulltext", "RemoveAction"=>"removeexpander(fulltext)"}]
      #   }
      def search_criteria_with_actions
        @results['SearchRequest']['SearchCriteriaWithActions']
      end

      # Retrieval criteria that was applied to the search. Returns a hash.
      # ==== Example
      #   {"View"=>"brief", "ResultsPerPage"=>20, "PageNumber"=>1, "Highlight"=>"y"}
      def retrieval_criteria
        @results['SearchRequest']['RetrievalCriteria']
      end
  
      # Queries used to produce the results. Returns an array of query hashes.
      # ==== Example
      #    [{"BooleanOperator"=>"AND", "Term"=>"volcano"}]
      def search_queries
        @results['SearchRequest']['SearchCriteria']['Queries']
      end

      # Current page number for the results. Returns an integer.
      def page_number
        @results['SearchRequest']['RetrievalCriteria']['PageNumber'] || 1
      end

      # List of facets applied to the search.
      # ==== Example
      #   [{
      #      "FacetValue"=>{"Id"=>"SubjectGeographic", "Value"=>"massachusetts"},
      #      "RemoveAction"=>"removefacetfiltervalue(1,SubjectGeographic:massachusetts)"
      #    }]
      def applied_facets
        af = []
        applied_facets_section = @results['SearchRequest'].fetch('SearchCriteriaWithActions',{}).fetch('FacetFiltersWithAction',{})
        applied_facets_section.each do |applied_facets|
          applied_facets.fetch('FacetValuesWithAction',{}).each do |applied_facet|
            af.push(applied_facet)
          end
        end
        af
      end

      # List of limiters applied to the search.
      # ==== Example
      #   [{
      #      "Id"=>"LA99",
      #      "LimiterValuesWithAction"=>[{"Value"=>"French", "RemoveAction"=>"removelimitervalue(LA99:French)"}],
      #      "RemoveAction"=>"removelimiter(LA99)"
      #   }]
      def applied_limiters
        af = []
        applied_limters_section = @results['SearchRequest'].fetch('SearchCriteriaWithActions',{}).fetch('LimitersWithAction',{})
        applied_limters_section.each do |applied_limter|
          af.push(applied_limter)
        end
        af
      end

      # Expanders applied to the search.
      # ==== Example
      #   [
      #      {"Id"=>"fulltext", "RemoveAction"=>"removeexpander(fulltext)"},
      #      {"Id"=>"thesaurus", "RemoveAction"=>"removeexpander(thesaurus)"},
      #      {"Id"=>"relatedsubjects", "RemoveAction"=>"removeexpander(relatedsubjects)"}
      #    ]
      def applied_expanders
        af = []
        applied_expanders_section = @results['SearchRequest'].fetch('SearchCriteriaWithActions',{}).fetch('ExpandersWithAction',{})
        applied_expanders_section.each do |applied_explander|
          af.push(applied_explander)
        end
        af
      end

      # Publications search was limited to.
      # ==== Example
      #   [
      #      ["Id", "eric"],
      #      ["RemoveAction", "removepublication(eric)"]
      #   ]
      def applied_publications
        retval = []
        applied_publications_section = @results['SearchRequest'].fetch('SearchCriteriaWithActions',{}).fetch('PublicationWithAction',{})
        applied_publications_section.each do |item|
          retval.push(item)
        end
        retval
      end

      # Provides a list of databases searched and the number of hits found in each one.
      # ==== Example
      #   [
      #      {:id=>"nlebk", :hits=>0, :label=>"eBook Collection (EBSCOhost)"},
      #      {:id=>"e000xna", :hits=>30833, :label=>"eBook Academic Collection (EBSCOhost)"},
      #      {:id=>"edsart", :hits=>8246, :label=>"ARTstor Digital Library"},
      #      {:id=>"e700xna", :hits=>6701, :label=>"eBook Public Library Collection (EBSCOhost)"},
      #      {:id=>"cat02060a", :hits=>3464, :label=>"EDS Demo Catalog – US - U of Georgia"},
      #      {:id=>"ers", :hits=>1329, :label=>"Research Starters"},
      #      {:id=>"asn", :hits=>136406, :label=>"Academic Search Ultimate"}
      #    ]
      def database_stats
        databases = []
        databases_facet = @results['SearchResult']['Statistics']['Databases']
        databases_facet.each do |database|
          if DBS.key?(database['Id'].upcase)
            db_label = DBS[database['Id'].upcase];
          else
            db_label = database['Label']
          end
          databases.push({id: database['Id'], hits: database['Hits'], label: db_label})
        end
        databases
      end

      # Provides a list of facets for the search results.
      # ==== Example
      #   [
      #      {
      #        :id=>"SourceType",
      #        :label=>"Source Type",
      #        :values=>[
      #          {
      #             :value=>"Academic Journals",
      #             :hitcount=>147,
      #             :action=>"addfacetfilter(SourceType:Academic Journals)"
      #          },
      #          {
      #             :value=>"News",
      #             :hitcount=>111,
      #             :action=>"addfacetfilter(SourceType:News)"
      #           },
      #
      #       ...
      #
      #      }
      #    ]
      def facets (facet_provided_id = 'all')
        facets_hash = []
        available_facets = @results.fetch('SearchResult',{}).fetch('AvailableFacets',{})
        available_facets.each do |available_facet|
          if available_facet['Id'] == facet_provided_id || facet_provided_id == 'all'
            facet_label = available_facet['Label']
            facet_id = available_facet['Id']
            facet_values = []
            available_facet['AvailableFacetValues'].each do |available_facet_value|
              facet_value = available_facet_value['Value']
              facet_count = available_facet_value['Count']
              facet_action = available_facet_value['AddAction']
              facet_values.push({value: facet_value, hitcount: facet_count, action: facet_action})
            end
            facets_hash.push(id: facet_id, label: facet_label, values: facet_values)
          end
        end
        facets_hash
      end

      # Returns a hash of the date range available for the search.
      # ==== Example
      #   {:mindate=>"1501-01", :maxdate=>"2018-04", :minyear=>"1501", :maxyear=>"2018"}
      def date_range
        mindate = @results['SearchResult']['AvailableCriteria']['DateRange']['MinDate']
        maxdate = @results['SearchResult']['AvailableCriteria']['DateRange']['MaxDate']
        minyear = mindate[0..3]
        maxyear = maxdate[0..3]
        {mindate: mindate, maxdate: maxdate, minyear:minyear, maxyear:maxyear}
      end

      # Provides alternative search terms to correct spelling, etc.
      # ==== Example
      #   results = session.simple_search('earthquak')
      #   results.did_you_mean
      #   => "earthquake"
      def did_you_mean
        dym_suggestions = @results.fetch('SearchResult', {}).fetch('AutoSuggestedTerms',{})
        dym_suggestions.each do |term|
          return term
        end
        nil
      end

      # Returns a simple list of the search terms used. Boolean operators are not indicated.
      # ==== Example
      #   ["earthquakes", "california"]
      def search_terms
        terms = []
        queries = @results.fetch('SearchRequest',{}).fetch('SearchCriteriaWithActions',{}).fetch('QueriesWithAction',{})
        queries.each do |query|
          query['Query']['Term'].split.each do |word|
            terms.push(word)
          end
        end
        terms
      end
  
    end

  end
end