require "test_helper"

class AccessControlTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { setup_boq }

  test "anonymous visitors must sign in" do
    get projects_path
    assert_redirected_to new_user_session_path
    get new_user_session_path
    assert_response :success
  end

  test "ordinary users can read projects but cannot create them" do
    @engineer.update!(role: :user)
    sign_in @engineer
    get projects_path
    assert_response :success
    assert_no_difference "Project.count" do
      post projects_path, params: { project: { name: "Blocked", code: "BLOCKED" } }
    end
    assert_response :forbidden
  end

  test "engineers can create a project and a plan with required codes" do
    sign_in @engineer
    post projects_path, params: { project: { name: "New site", code: "NEW-SITE", location: "Bangkok" } }
    assert_redirected_to projects_path
    project = Project.find_by!(code: "NEW-SITE")
    post project_house_plans_path(project), params: { house_plan: { name: "Plan A", plan_code: "A" } }
    assert_redirected_to project_house_plans_path(project)
    assert_equal "A", project.house_plans.first.plan_code
  end

  test "project and plan screens render the styled layout" do
    sign_in @engineer
    [ projects_path, project_path(@project), new_project_path, edit_project_path(@project),
      project_house_plans_path(@project), new_project_house_plan_path(@project),
      edit_project_house_plan_path(@project, @plan) ].each do |path|
      get path
      assert_response :success
      assert_select "link[rel='stylesheet'][href*='tailwind']"
      assert_select "main#main-content"
    end
  end
end
