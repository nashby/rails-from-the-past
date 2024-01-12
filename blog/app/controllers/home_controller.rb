class HomeController < ActionController::Base
  def foo
    render_template <<-"EOF"
      <html><body>
        Hello!
      </body></html>
    EOF
  end
end
