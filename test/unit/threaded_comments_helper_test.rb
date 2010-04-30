require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper.rb'))

class ThreadedCommentsHelperTest < ActionView::TestCase

  include ThreadedCommentsHelper
  
  def setup
    @test_book = Book.create!(Factory.attributes_for(:book))
    @test_comments = complex_thread(2)
    @rendered_html = render_threaded_comments(@test_comments)
  end

  test "render_threaded_comments should output comment names" do
    @test_comments.each do |comment|
      assert @rendered_html.include?(comment.name), "Did not include comment name"
    end
  end
  
  test "render_threaded_comments should output comment bodies" do
    @test_comments.each do |comment|
      assert @rendered_html.include?(comment.body), "Did not include comment body"
    end
  end
  
  test "render_threaded_comments should output comment creation times" do
    @test_comments.each do |comment|
      assert @rendered_html.include?(time_ago_in_words(comment.created_at)), "Did not include comment creation time"
    end
  end
  
  test "render_threaded_comment options and config" do
    test_option "rating text", "enable_rating", "threaded_comment_rating_:id"
    test_option "upmod button", "enable_rating", link_to_remote('', :url => {:controller => "threaded_comments", :action => "upmod", :id => ":id"})
    test_option "downmod button", "enable_rating", link_to_remote('', :url => {:controller => "threaded_comments", :action => "downmod", :id => ":id"})
    test_option "flag button", "enable_flagging", link_to_remote('', :url => {:controller => "threaded_comments", :action => "flag", :id => ":id"})
    test_option "flag button container", "enable_flagging", "flag_threaded_comment_container_:id"
    test_option "flag message", "flag_message", "Are you really sure you want to flag this comment?"
    test_option "permalinks", "enable_permalinks", "#threaded_comment_:id"
    test_option "reply link text", "reply_link_text", "Reply"
  end
  
  
  
  # Stub out some of ActionView's helpers so we can test *our* helpers in isolation
  def link_to_remote(*args)
    if( args.last.is_a?(Hash))
      url = args.last[:url]
      url = "/#{url[:controller]}/#{url[:action]}/#{url[:id]}"
    end
    if( args.first.is_a?(String))
      "<a href=\"#{url}\">#{args.first}</a>"
    else
      ""
    end
  end
  
  def time_ago_in_words(*args)
    "30 minutes ago"
  end
  
  private
  
    def test_option(name, option_name, pattern, namespace = 'render_threaded_comments')
      assert defined?(THREADED_COMMENTS_CONFIG[namespace][option_name]), "The option name '#{namespace}:#{option_name}' was not set in the default config"
      if(THREADED_COMMENTS_CONFIG[namespace][option_name].is_a?(TrueClass) or THREADED_COMMENTS_CONFIG[namespace][option_name].is_a?(FalseClass))
        # Enabled in config - not set in options
        change_config_option(namespace, option_name, true) do
          rendered_html = render_threaded_comments(@test_comments)
          @test_comments.each do |comment|
            assert rendered_html.include?(pattern.gsub(":id", comment.id.to_s)), "render_threaded_comments did not output '#{pattern.gsub(":id", comment.id.to_s)}' with '#{namespace}:#{option_name}' enabled in config"
          end
        end
        # Disabled in config - not set in options
        change_config_option(namespace, option_name, false) do
          rendered_html = render_threaded_comments(@test_comments)
          @test_comments.each do |comment|
            assert !rendered_html.include?(pattern.gsub(":id", comment.id.to_s)), "render_threaded_comments should not output '#{pattern.gsub(":id", comment.id.to_s)}' when '#{namespace}:#{option_name}' disabled in config"
          end
        end
        # Enabled in options - disabled in config - options should override
        change_config_option(namespace, option_name, false) do
          rendered_html = render_threaded_comments(@test_comments, option_name => true)
          @test_comments.each do |comment|
            assert rendered_html.include?(pattern.gsub(":id", comment.id.to_s)), "render_threaded_comments did not output '#{pattern.gsub(":id", comment.id.to_s)}' when '#{namespace}:#{option_name}' enabled in options"
          end
        end
        # Disabled in options - enabled in config - options should override
        change_config_option(namespace, option_name, true) do
          rendered_html = render_threaded_comments(@test_comments, option_name => false)
          @test_comments.each do |comment|
            assert !rendered_html.include?(pattern.gsub(":id", comment.id.to_s)), "render_threaded_comments should not output '#{pattern.gsub(":id", comment.id.to_s)}' when '#{namespace}:#{option_name}' disabled in options"
          end
        end
      elsif(THREADED_COMMENTS_CONFIG[namespace][option_name].is_a?(String))
        # Default - should be set in config
        rendered_html = render_threaded_comments(@test_comments)
        assert_equal @test_comments.length, rendered_html.split(pattern).length - 1, "render_threaded_comments did not output '#{pattern}' for each comment by default"
        # Set in config - not set in options
        change_config_option(namespace, option_name, "replacement_pattern_config") do
          rendered_html = render_threaded_comments(@test_comments)
          assert_equal @test_comments.length, rendered_html.split("replacement_pattern_config").length - 1, "render_threaded_comments did not output value of '#{namespace}:#{option_name}' for each comment when set in config"
          assert_equal 1, rendered_html.split(pattern), "render_threaded_comments still output default value of '#{namespace}:#{option_name}' even when overwritten in config"
        end
        # Set in options - also set in config - options should override
        change_config_option(namespace, option_name, "replacement_pattern_config") do
          rendered_html = render_threaded_comments(@test_comments, option_name => "replacement_pattern_options")
          assert_equal @test_comments.length, rendered_html.split("replacement_pattern_options").length - 1, "render_threaded_comments did not output value of '#{namespace}:#{option_name}' for each comment when set in options"
          assert_equal 1, rendered_html.split(pattern), "render_threaded_comments still output default value of '#{namespace}:#{option_name}' even when overwritten in config and options"
          assert_equal 1, rendered_html.split("replacement_pattern_config"), "render_threaded_comments still output config value of '#{namespace}:#{option_name}' even when overwritten in options"
        end
      else
        flunk "Unrecognized option type: #{THREADED_COMMENTS_CONFIG[namespace][option_name].class}"
      end
    end
  
    def complex_thread(length=100)
      comments = []
      length.times do
        comments << parent_comment = Factory.build(:threaded_comment)
        3.times do
          comments << subcomment1 = Factory.build(:threaded_comment, :parent_id => parent_comment.id)
          2.times do
            comments << subcomment2 = Factory.build(:threaded_comment, :parent_id => subcomment1.id)
            2.times do
              comments << subcomment3 = Factory.build(:threaded_comment, :parent_id => subcomment2.id)
            end
          end
        end
      end
      comments
    end
    
    def change_config_option(namespace, key, value, &block)
      old_config = THREADED_COMMENTS_CONFIG.dup
      old_stderr = $stderr
      $stderr = StringIO.new
      THREADED_COMMENTS_CONFIG[namespace][key] = value
      $stderr = old_stderr
      yield block
    ensure
      $stderr = StringIO.new
      Kernel.const_set('THREADED_COMMENTS_CONFIG', old_config)
      $stderr = old_stderr
    end

end
