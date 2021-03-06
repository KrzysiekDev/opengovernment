class MoneyTrailsController < SubdomainController
  before_filter :get_industry, :only => [:show]

  def index
    # We call .all here so we can execute the query now, due to a 
    # Rails bug with .count and .size
    @industries = Industry.aggregates_for_state(@state.id).order('industries.transparencydata_order').all
    
    # Build a sectors hash we can use for display.
    @sectors = {}
    Industry.where("transparencydata_code like '_0000'").map { |s| @sectors[s.transparencydata_code] =  [s.name, []]}
    @sectors["Z0000"] = ["Other", []]

    @industries.each do |i|
      @sectors[i.transparencydata_code.at(0) + '0000'][1] << i
    end

    @sectors.values.each do |s|
      s[1] = s[1].sort_by {|i| i.name }
    end

  end

  def show
    @contributions = Contribution.find_by_sql([%q{SELECT contributions.contributor_name, sum(contributions.amount) as amount FROM "contributions" INNER JOIN "industries" ON "contributions".industry_id = "industries".transparencydata_code WHERE "industries".transparencydata_code = ? AND ("contributions"."state_id" = ?) GROUP BY contributions.contributor_name ORDER BY amount desc LIMIT 20}, @industry.id, @state.id])
    
    @recipients = Contribution.find_by_sql([%q{SELECT contributions.person_id, sum(contributions.amount) as amount FROM "contributions" INNER JOIN "industries" ON "contributions".industry_id = "industries".transparencydata_code WHERE "industries".transparencydata_code = ? AND "contributions"."state_id" = ? GROUP BY contributions.person_id ORDER BY amount desc LIMIT 20}, @industry.id, @state.id])

    # TODO: These -should- work and did work, but are broken in Rails 3.0.3
    # @contributions = @industry.contributions.for_state(@state.id).grouped_by_name.limit(20).all
    # @recipients = @industry.contributions.for_state(@state.id).grouped_by_recipient.limit(20).all
  end

  protected
  def get_industry
    @industry = Industry.find(params[:id][0..4].upcase)
  end
end
