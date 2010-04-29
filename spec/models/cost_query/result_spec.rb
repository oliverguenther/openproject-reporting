require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe CostQuery do
  before { @query = CostQuery.new }

  fixtures :users
  fixtures :cost_types
  fixtures :cost_entries
  fixtures :rates
  fixtures :projects
  fixtures :issues
  fixtures :trackers
  fixtures :time_entries
  fixtures :enumerations
  fixtures :issue_statuses
  fixtures :roles
  fixtures :issue_categories
  fixtures :versions

  describe CostQuery::Result do
    def direct_results(quantity = 0)
      (1..quantity).collect {|i| CostQuery::Result.new :real_costs=>i.to_f, :count=>1 ,:units=>i.to_f}
    end

    def wrapped_result(source, quantity=1)
      CostQuery::Result.new((1..quantity).collect { |i| source})
    end

    it "should travel recursively depth-first" do
      #build a tree of wrapped and direct results
      w1 = wrapped_result((direct_results 5), 3)
      w2 = wrapped_result wrapped_result((direct_results 3), 2)
      w = wrapped_result [w1, w2]

      found_direct_result = false
      previous_depth = -1
      w.recursive_each_with_level do |level, result|
        #depth first, so we should get deeper into the hole, until we find a direct_result
        unless found_direct_result
          previous_depth.should == level - 1
          previous_depth=level
        end
        found_direct_result = true if result.is_a? CostQuery::Result::DirectResult
      end
    end

    it "should compute count correctly" do
      @query.result.count.should == Entry.count
    end

    it "should compute units correctly" do
      @query.result.units.should == Entry.all.map { |e| e.units}.sum
    end

    it "should compute real_costs correctly" do
      @query.result.real_costs.should == Entry.all.map { |e| e.overridden_costs || e.costs}.sum
    end

    it "should compute count for DirectResults" do
      @query.result.values[0].count.should == 1
    end

    it "should compute units for DirectResults" do
      id_sorted = @query.result.values.sort_by { |r| r[:id] }
      te_result = id_sorted.select { |r| r[:type]==TimeEntry.to_s }.first
      ce_result = id_sorted.select { |r| r[:type]==CostEntry.to_s }.first

      te_result.units.should == TimeEntry.all.first.hours
      ce_result.units.should == CostEntry.all.first.units
    end

    it "should compute real_costs for DirectResults" do
      id_sorted = @query.result.values.sort_by { |r| r[:id] }

      [TimeEntry, CostEntry].each do |type|
        result = id_sorted.select { |r| r[:type]==type.to_s }.first
        first = type.all.first
        result.real_costs.should == (first.overridden_costs || first.costs)
      end
    end

  end
end