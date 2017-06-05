require 'rails_helper'

RSpec.describe Formatter do
  let(:account)       { Fabricate(:account, username: 'alice') }
  let(:local_text)    { 'Hello world http://google.com' }
  let(:local_status)  { Fabricate(:status, text: local_text, account: account) }
  let(:remote_status) { Fabricate(:status, text: '<script>alert("Hello")</script> Beep boop', uri: 'beepboop', account: account) }

  let(:local_text_with_mention) { "@#{account.username} @#{account.username}@example.com #{local_text}?x=@#{account.username} #hashtag" }

  let(:local_status_with_mention) do
    Fabricate(
      :status,
      text: local_text_with_mention,
      account: account,
      mentions: [Fabricate(:mention, account: account)]
    )
  end

  describe '#format' do
    subject { Formatter.instance.format(local_status) }

    context 'with standalone status' do
      it 'returns a string' do
        expect(subject).to be_a String
      end

      it 'contains plain text' do
        expect(subject).to match('Hello world')
      end

      it 'contains a link' do
        expect(subject).to match('<a href="http://google.com/" rel="nofollow noopener" target="_blank"><span class="invisible">http://</span><span class="">google.com/</span><span class="invisible"></span></a>')
      end

      it 'contains a mention' do
        result = Formatter.instance.format(local_status_with_mention)
        expect(result).to match "<a href=\"#{TagManager.instance.url_for(account)}\" class=\"u-url mention\">@<span>#{account.username}</span></a></span>"
        expect(result).to match %r{href=\"http://google.com/\?x=@#{account.username}}
        expect(result).not_to match "href=\"https://example.com/@#{account.username}"
      end

      it 'contains a hashtag' do
        result = Formatter.instance.format(local_status_with_mention)
        expect(result).to match('/tags/hashtag" class="mention hashtag" rel="tag">#<span>hashtag</span></a>')
      end
    end

    context 'with cashtag' do
      let(:local_text) { 'Hello world $AAPL' }

      it 'skip cashtag' do
        expect(subject).to match '<p>Hello world $AAPL</p>'
      end
    end

    context 'with reblog' do
      let(:local_status) { Fabricate(:status, account: account, reblog: Fabricate(:status, text: 'Hello world', account: account)) }

      it 'contains credit to original author' do
        expect(subject).to include("RT <span class=\"h-card\"><a href=\"#{TagManager.instance.url_for(account)}\" class=\"u-url mention\">@<span>#{account.username}</span></a></span> Hello world")
      end
    end

    context 'matches a stand-alone medium URL' do
      let(:local_text) { 'https://hackernoon.com/the-power-to-build-communities-a-response-to-mark-zuckerberg-3f2cac9148a4' }

      it 'has valid url' do
        expect(subject).to include('href="https://hackernoon.com/the-power-to-build-communities-a-response-to-mark-zuckerberg-3f2cac9148a4"')
      end
    end

    context 'matches a stand-alone google URL' do
      let(:local_text) { 'http://google.com' }

      it 'has valid url' do
        expect(subject).to include('href="http://google.com/"')
      end
    end

    context 'matches a stand-alone IDN URL' do
      let(:local_text) { 'https://nic.みんな/' }

      it 'has valid url' do
        expect(subject).to include('href="https://nic.xn--q9jyb4c/"')
      end

      it 'has display url' do
        expect(subject).to include('<span class="">nic.みんな/</span>')
      end
    end

    context 'matches a URL without trailing period' do
      let(:local_text) { 'http://www.mcmansionhell.com/post/156408871451/50-states-of-mcmansion-hell-scottsdale-arizona. ' }

      it 'has valid url' do
        expect(subject).to include('href="http://www.mcmansionhell.com/post/156408871451/50-states-of-mcmansion-hell-scottsdale-arizona"')
      end
    end

    xit 'matches a URL without closing paranthesis' do
      expect(subject.match('(http://google.com/)')[0]).to eq 'http://google.com'
    end

    context 'matches a URL without exclamation point' do
      let(:local_text) { 'http://www.google.com!' }

      it 'has valid url' do
        expect(subject).to include('href="http://www.google.com/"')
      end
    end

    context 'matches a URL without single quote' do
      let(:local_text) { "http://www.google.com'" }

      it 'has valid url' do
        expect(subject).to include('href="http://www.google.com/"')
      end
    end

    context 'matches a URL without angle brackets' do
      let(:local_text) { 'http://www.google.com>' }

      it 'has valid url' do
        expect(subject).to include('href="http://www.google.com/"')
      end
    end

    context 'matches a URL with a query string' do
      let(:local_text) { 'https://www.ruby-toolbox.com/search?utf8=%E2%9C%93&q=autolink' }

      it 'has valid url' do
        expect(subject).to include('href="https://www.ruby-toolbox.com/search?utf8=%E2%9C%93&amp;q=autolink"')
      end
    end

    context 'matches a URL with parenthesis in it' do
      let(:local_text) { 'https://en.wikipedia.org/wiki/Diaspora_(software)' }

      it 'has valid url' do
        expect(subject).to include('href="https://en.wikipedia.org/wiki/Diaspora_(software)"')
      end
    end

    context 'contains html (script tag)' do
      let(:local_text) { '<script>alert("Hello")</script>' }

      it 'has valid url' do
        expect(subject).to match '<p>&lt;script&gt;alert(&quot;Hello&quot;)&lt;/script&gt;</p>'
      end
    end

    context 'contains html (xss attack)' do
      let(:local_text) { %q{<img src="javascript:alert('XSS');">} }

      it 'has valid url' do
        expect(subject).to match '<p>&lt;img src=&quot;javascript:alert(&apos;XSS&apos;);&quot;&gt;</p>'
      end
    end

    context 'contains invalid URL' do
      let(:local_text) { 'http://www\.google\.com' }

      it 'has valid url' do
        expect(subject).to eq '<p>http://www\.google\.com</p>'
      end
    end

    context 'concatenates hashtag and URL' do
      let(:local_text) { '#hashtaghttps://www.google.com' }

      it 'has valid hashtag' do
        expect(subject).to match('/tags/hashtag" class="mention hashtag" rel="tag">#<span>hashtag</span></a>')
      end
    end
  end

  describe '#reformat' do
    subject { Formatter.instance.format(remote_status) }

    it 'returns a string' do
      expect(subject).to be_a String
    end

    it 'contains plain text' do
      expect(subject).to match('Beep boop')
    end

    it 'does not contain scripts' do
      expect(subject).to_not match('<script>alert("Hello")</script>')
    end
  end
end
