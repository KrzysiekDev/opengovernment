class StatesController < ApplicationController
  before_filter :get_state

  def show
    if @state.supported?
      session[:preferred_location] = request.subdomains.first
      
      @legislature = @state.legislature
      @most_recent_session = Session.most_recent(@legislature).first

      @state_key_votes = Bill.where(:votesmart_key_vote => true, :state_id => @state.id).limit(5)
    else
      render :template => 'states/unsupported', :layout => 'home'
    end
  end

  def subscribe
    if request.post?
      @state.subscriptions.build(:email => params[:email])
      if @state.save
        redirect_to(root_path) and return
      end
    else
    end
  end

  def search
    @query = params[:q] || ""
    @search_type = params[:search_type] || "all"
    @committee_type = params[:committee_type] || "all"

    # Because we are rendering a partial with @search_type in the filename,
    # sanitize this param.
    unless ['all','legislators','bills','committees','contributions'].include? @search_type
      @search_type = 'all'
    end

    # We might be able to stop right here and redirect to a bill.
    # This is specifically for searched bill numbers.  Re-directing to a single
    # match in the generic case is handled below
    case @search_type
    when 'all', 'bills'
      if @bills = Bill.for_state(@state).with_number(@query)
        if @bills.size == 1
          redirect_to(bill_path(@bills.first.session, @bills.first)) and return
        end
      end
    end

    @search_options = {
      :page => params[:page],
      :per_page => 15,
      :order => params[:order],
      :with => { :state_id => @state.id }
    }

    @search_options[:with].merge!(:session_id => params[:session_id]) if params[:session_id]

    case @committee_type
      when "all"
        @committee_type = Committee
      else
        @committee_type = "#{params[:committee_type]}_committee".classify.constantize
    end
    
    if @query
      case @search_type
        when "all"
          @legislators = Person.search(@query, @search_options)
          @bills = @state.bills.search(@query, @search_options)
          @contributions = Contribution.search(@query, @search_options)
          @committees = @committee_type.search(@query, @search_options)
          @total_entries = @legislators.total_entries + @bills.total_entries + @contributions.total_entries + @committees.total_entries
        when "bills"
          @bills = @state.bills.search(@query, @search_options)
          @total_entries = @bills.total_entries
        when "legislators"
          @legislators = Person.search(@query, @search_options)
          @total_entries = @legislators.total_entries
        when "committees"
          @committees = @committee_type.search(@query, @search_options)
          @total_entries = @committees.total_entries
        when "contributions"
          @contributions = Contribution.search(@query, @search_options)
          @total_entries = @contributions.total_entries
      end
      
      if @total_entries == 1
        # go straight to the page for this object
        if @legislators && @legislators.total_entries == 1
          redirect_to @legislators.first
        elsif @bills && @bills.total_entries == 1
          redirect_to bill_path(@bills.first.session, @bills.first)
        elsif @committees && @committees.total_entries == 1
          redirect_to committee_path(@committees.first)
        end
      end
    else
      render :nothing => true
    end
  end

end
