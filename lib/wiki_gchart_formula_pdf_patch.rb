# coding: UTF-8

# Copyright (C) 2011 by Masamitsu MURASE
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_dependency 'redmine/export/pdf'
require 'wiki_gchart_formula'
require 'wiki_gchart_formula_macro'

if WikiGchartFormula.support_pdf?

module WikiGchartFormula
  class WikiGchartFormulaTempPngManager
    class << self
      def create_temp_png_files(data, &block)
        manager = self.new(data)
        begin
          block.call(manager)
        ensure
          manager.release
        end
      end
    end

    def initialize(data)
      @temp_png_files = {}
      data ||= []
      data.each do |item|
        key = item[:key]
        png_data = item[:png].unpack("m")[0]

        Tempfile.open([ "gchart_", ".png" ]) do |file|
          file.binmode if (file.respond_to?(:binmode))
          file.write(png_data)
          @temp_png_files[key] = file
        end
      end
    end

    def exist?(url)
      key = chl(CGI.unescapeHTML(url))
      return @temp_png_files.key?(key)
    end

    def temp_file(url)
      key = chl(CGI.unescapeHTML(url))
      return @temp_png_files[key]
    end

    def release
      @temp_png_files.each{ |key, value| value.close! }
      @temp_png_files.clear
    end

    private
    def chl(url)
      pat = /(\?|&)chl=([^&]+)/
      match_data = url.match(pat)
      return match_data ? match_data[2] : nil
    end
  end
end


module WikiGchartFormula
  class IssueListener < Redmine::Hook::ViewListener
    PDF_FORM_ID = 'wiki_gchart_formula_pdf_form'

    def view_layouts_base_html_head(context)
      if context[:controller].controller_name == 'issues' && context[:controller].action_name == 'show'
        config = <<"EOS"
var gWikiGchartFormula = {
  img_class: '#{escape_javascript(WikiGchartFormulaMacro::IMAGE_TAG_CLASS_NAME)}',
  pdf_form_id: '#{escape_javascript(PDF_FORM_ID)}'
};
EOS
        return javascript_tag(config) +
          javascript_include_tag('wiki_gchart_formula.js', :plugin => 'redmine_wiki_gchart_formula')
      end
      ''
    end

    def view_layouts_base_body_bottom(context)
      if context[:controller].controller_name == 'issues' && context[:controller].action_name == 'show'
        return context[:controller].send(:render_to_string, {
                                           :partial => 'wiki_gchart_formula/issue_pdf_form',
                                           :locals => { :issue_id => context[:controller].params[:id] }
                                         })
      end
      ''
    end
  end
end

end
