require 'spec_helper'

describe "DataAnalysis API", type: :request do
  before(:each) do
    admin_user = create_admin_user
    post '/login', { email: admin_user.email, password: admin_user.password }
    @experiment = create_experiment_for_data_analysis("dataanalysis")
    run_experiment(@experiment)
  end
  
  def amplification_data_length(num_cycles)
    num_cycles*16*2+1
  end
  
  it "all temperature data" do
    totallength = @experiment.temperature_logs.length
    get "/experiments/#{@experiment.id}/temperature_data?starttime=0&resolution=1000", { :format => 'json' }
    expect(response).to be_success
    json = JSON.parse(response.body)
    json.length.should eq(totallength)
  end
  
  it "temperature data every 2 second" do
    totallength = @experiment.temperature_logs.length
    get "/experiments/#{@experiment.id}/temperature_data?starttime=0&resolution=2000", { :format => 'json' }
    expect(response).to be_success
    json = JSON.parse(response.body)
    json.length.should eq((totallength+1)/2)
  end
  
  it "temperature data every 3 second" do
    totallength = @experiment.temperature_logs.length
    get "/experiments/#{@experiment.id}/temperature_data?starttime=0&resolution=3000", { :format => 'json' }
    expect(response).to be_success
    json = JSON.parse(response.body)
    json.length.should eq((totallength+2)/3)
  end
  
  it "amplification data with async calls" do
    create_fluorescence_data(@experiment, 10)
    expect_any_instance_of(ExperimentsController).to receive(:calculate_amplification_data) do |obj, experiment, stage_id, calibration_id|
      experiment.id.should == @experiment.id
      calibration_id.should == @experiment.calibration_id
      sleep(2)
      [[], []]
    end
    
    #data processing
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }
    response.response_code.should == 202
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }
    print response.body
    response.response_code.should == 202
    sleep(2)

    #data available
    stage, step = create_amplification_and_cq_data(@experiment, 10)
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }
    response.response_code.should == 200
    response.etag.should_not be_nil
    json = JSON.parse(response.body)
    json["partial"].should eq(true)
    json["total_cycles"].should eq(stage.num_cycles)
    json["steps"][0]["step_id"].should eq(step.id)
    json["steps"][0]["amplification_data"].length.should == 11 #include header
    json["steps"][0]["amplification_data"][0].join(",").should eq("target_id,well_num,cycle_num,background_subtracted_value,baseline_subtracted_value,dr1_pred,dr2_pred")
    json["steps"][0]["summary_data"].should_not be_nil

    #data cached
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json'}, { "If-None-Match" => response.etag }
    response.response_code.should == 304
    #response.body should be_nil
  end
  
  it "amplification data with more data" do
    create_fluorescence_data(@experiment, 10)
    
    expect_any_instance_of(ExperimentsController).to receive(:calculate_amplification_data) do |obj, experiment, stage_id, calibration_id|
      experiment.id.should == @experiment.id
      calibration_id.should == @experiment.calibration_id
      sleep(1)
      [[], []]
    end
      
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }
    response.response_code.should == 202
    
    sleep(2)
    
    stage, step = create_amplification_and_cq_data(@experiment, 10)
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }
    response.response_code.should == 200
    json = JSON.parse(response.body)
    json["partial"].should eq(true)
    json["total_cycles"].should eq(stage.num_cycles)
    json["steps"][0]["step_id"].should eq(step.id)
    json["steps"][0]["amplification_data"].length.should == 11 #include header
    
    #more data are added
    create_fluorescence_data(@experiment, 10, 10)
    stage, step = create_amplification_and_cq_data(@experiment, 10, 10)
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }
    #return data for the 20 rows
    response.response_code.should == 200
    json = JSON.parse(response.body)
    json["partial"].should eq(true)
    json["total_cycles"].should eq(stage.num_cycles)
    json["steps"][0]["step_id"].should eq(step.id)
    json["steps"][0]["amplification_data"].length.should == 21 #include header
  
    #add all the data for this stage
    create_fluorescence_data(@experiment, 0, 20)
    stage, step = create_amplification_and_cq_data(@experiment, 0, 20)  
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }
    response.response_code.should == 200
    json = JSON.parse(response.body)
    json["partial"].should eq(false)
    json["total_cycles"].should eq(stage.num_cycles)
    json["steps"][0]["step_id"].should eq(step.id)
    json["steps"][0]["amplification_data"].length.should == amplification_data_length(stage.num_cycles)  
  end
  
  it "amplification data raw" do
    create_fluorescence_data(@experiment, 0)
    get "/experiments/#{@experiment.id}/amplification_data?raw=true", { :format => 'json' }
    expect(response).to be_success
    response.etag.should_not be_nil
    stage = Stage.collect_data(@experiment.experiment_definition_id).first
    step = Step.collect_data(stage.id).first
    json = JSON.parse(response.body)
    json["partial"].should eq(false)
    json["total_cycles"].should eq(stage.num_cycles)
    json["steps"][0]["step_id"].should eq(step.id)
    json["steps"][0]["amplification_data"].length.should == amplification_data_length(stage.num_cycles) 
    json["steps"][0]["amplification_data"][0].join(",").should eq("target_id,well_num,cycle_num,fluorescence_value")
    json["steps"][0]["amplification_data"][1][0].should == 1
    json["steps"][0]["amplification_data"][1][1].should == 1
    json["steps"][0]["summary_data"].should be_nil
  
    #data cached  
    get "/experiments/#{@experiment.id}/amplification_data?raw=true", { :format => 'json'}, { "If-None-Match" => response.etag }
    response.response_code.should == 304
  end
  
  it "amplification data for error" do
    create_fluorescence_data(@experiment, 10)
    error = "test error"
    expect_any_instance_of(ExperimentsController).to receive(:calculate_amplification_data) do |obj, experiment, stage_id, calibration_id|
      raise ({errors: error}.to_json)
    end
    
    #request submitted
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }
    response.response_code.should == 202
    
    #error returns
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }
    response.response_code.should == 500
    json = JSON.parse(response.body)
    json["errors"].should eq(error)
    
    #resubmit request
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }
    response.response_code.should == 202
  end
  
  it "amplification data for aborted" do
    create_fluorescence_data(@experiment, 10)
    finish_experiment(@experiment)
    stage, step = create_amplification_and_cq_data(@experiment, 10)
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }
    response.response_code.should == 200
    json = JSON.parse(response.body)
    json["partial"].should eq(false)
    json["total_cycles"].should eq(stage.num_cycles)
    json["steps"][0]["step_id"].should eq(step.id)
    json["steps"][0]["amplification_data"].length.should == 11 #include header
  end
  
  it "amplification data for two experiments" do
    create_fluorescence_data(@experiment, 10)
    expect_any_instance_of(ExperimentsController).to receive(:calculate_amplification_data) do |obj, experiment, stage_id, calibration_id|
      experiment.id.should == @experiment.id
      calibration_id.should == @experiment.calibration_id
      sleep(2)
      [[], []]
    end
    
    #data processing
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }
    response.response_code.should == 202
    
    #2nd experiment
    experiment2 = create_experiment_for_data_analysis("dataanalysis2")
    run_experiment(experiment2)
    create_fluorescence_data(experiment2, 10)
        
    get "/experiments/#{experiment2.id}/amplification_data", { :format => 'json' }
    response.response_code.should == 503
    
    sleep(2)

    #data available
    stage, step = create_amplification_and_cq_data(@experiment, 10)
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }
    response.response_code.should == 200
  end  
  
  it "summary data for replic group" do
    create_sample_for_wells(@experiment, "Sample 1", [1,6,9])
    create_sample_for_wells(@experiment, "Sample 2", [2,10,14])
    create_sample_for_wells(@experiment, "Sample 3", [3,7,11])
    create_sample_for_wells(@experiment, "Sample 4", [4,12,15])
    create_sample_for_wells(@experiment, "Sample 5", [5,8,13])
    
    create_target_for_wells_csv(@experiment, "Target 1", 1, "spec/fixtures/targets_wells.csv")
    
    create_fluorescence_data(@experiment, 0, 20)
    stage, step = create_amplification_and_cq_data(@experiment, 0, 20)  
    
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }
    response.response_code.should == 200
    json = JSON.parse(response.body)
    expected_response=[[1,1,nil,1.0,0,0,1.0,0],
              [6,1,nil,1.0,0,0,1.0,0],
              [9,1,nil,1.0,0,0,1.0,0],
              [2,2,nil,1.0,-1,0,1.0,-1],
              [10,2,nil,1.0,-1,0,1.0,-1],
              [14,2,nil,1.0,-1,0,1.0,-1],
              [3,3,nil,1.0,-2,0,1.0,-2],
              [7,3,nil,1.0,-2,0,1.0,-2],
              [11,3,nil,1.0,-2,0,1.0,-2],
              [4,4,nil,1.0,-3,0,1.0,-3],
              [12,4,nil,1.0,-3,0,1.0,-3],
              [15,4,nil,1.0,-3,0,1.0,-3],
              [5,5,nil,1.0,-4,0,1.0,-4],
              [8,5,nil,1.0,-4,0,1.0,-4],
              [13,5,nil,1.0,-4,0,1.0,-4]]
              
    summary_data = json["steps"][0]["summary_data"]
    summary_data.shift
    summary_data.each_with_index do |row, index|
      row.shift
      row.each_with_index do |val, valindex|
        val.should == expected_response[index][valindex]
      end
    end
  end
  
  it "add target will trigger amplification_data reload" do
    create_fluorescence_data(@experiment, 0, 20)
    stage, step = create_amplification_and_cq_data(@experiment, 0, 20)  
    
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }
    response.response_code.should == 200
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }, { "If-None-Match" => response.etag }
    response.response_code.should == 304
    
    create_target_for_wells(@experiment, "Target 1", 1, [6])
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }, { "If-None-Match" => response.etag }
    response.response_code.should == 200
    get "/experiments/#{@experiment.id}/amplification_data", { :format => 'json' }, { "If-None-Match" => response.etag }
    response.response_code.should == 304
  end
  
=begin    
  it "export" do
    experiment = create_experiment("test1")
    run_experiment(experiment)
    create_fluorescence_data(experiment, 0)
    get "/experiments/#{experiment.id}/export", { :format => 'zip' }
    expect(response).to be_success
  end
=end
end