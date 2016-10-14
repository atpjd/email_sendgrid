<?=

//debug->activate

define email_sendgrid => type {
	
	data public subject::string=''
	data public from::string
	data public to
	data public cc
	data public bcc
	data public body=''
	data public html=''
	data public attachments::array=array
	data public replyto::string=''
	data public extramimeheaders::array=array
	data public payload::map=map
	data public categories::set=set
	data public send_at
	data private personalizations_template=array(map())
	
	private apiurl => 'https://api.sendgrid.com/v3/mail/send'
	private apikey => '' // insert your API key here

	private splitAddresses(obj) => debug => {

		local(new = set)

		#obj->isa(::string) ? #obj = #obj->split(',')

		with i in #obj where #i->isa(::string) do => {
			#i->trim
			#new->insert(#1)
		}

		#new->remove('')

		return #new
	}

	public onCreate(
		-subject::string='',
		-from::string,
		-to,
		-cc='',
		-bcc='',
		-body='',
		-html='',
		-attachments::array=array,
		-replyto='',
		-extraMIMEHeaders::array=array,
		-categories::array=array,
		-date=null,
		-debug::boolean=false
	) => debug => {
		
		.subject = #subject
		.from = #from
		.to = .splitAddresses(#to)
		.cc = .splitAddresses(#cc)
		.bcc = .splitAddresses(#bcc)
		.body = #body
		.html = #html
		.attachments = #attachments
		.replyto = #replyto
		.extramimeheaders = #extramimeheaders
		.send_at = #date
		
		with i in .categories do => { // de-duplicate
			.categories->insert(#i)
		}
		
		.generatePayload()
		
		!#debug ? .send()

	}

	private generatePayload() => debug => {

		.payload->insert('personalizations' = array(map))
		local(personalizations) = .payload->get('personalizations')

		// TO
		if(.to->size) => {
			#personalizations->first->insert('to' = array)
			local(to) = #personalizations->first->get('to')
			with i in .to do => {
				#to->insert(map('email' = #i))
			}
		}

		// CC
		if(.cc->size) => {
			#personalizations->first->insert('cc' = array)
			local(cc) = #personalizations->first->get('to')
			with i in .cc do => {
				#cc->insert(map('email' = #i))
			}
		}

		// BCC
		if(.bcc->size) => {
			#personalizations->first->insert('bcc' = array)
			local(bcc) = #personalizations->first->get('to')
			with i in .bcc do => {
				#bcc->insert(map('email' = #i))
			}
		}

		// FROM
		.payload->insert('from' = map('email' = .from))
		
		// REPLY-TO
		.replyto ? .payload->insert('reply_to' = map('email' = .replyto))

		// SUBJECT
		.payload->insert('subject' = .subject)
		
		// CONTENT
		.payload->insert('content' = array)
		local(content) = .payload->get('content')
		if(.body) => {
			#content->insert(map('type' = 'text/plain', 'value' = .body))
		}

		if(.html) => {
			#content->insert(map('type' = 'text/html', 'value' = .html))
		}
		
		// EXTRA MIME HEADERS
		if(.extramimeheaders->size) => {
			.payload->insert('headers' = map)
			local(headers) = .payload->get('headers')
			with i in .extramimeheaders do => {
				#headers->insert(#i->first = #i->second)
			}
		}
		
		// CATEGORIES
		if(.categories->size) => {
			.payload->insert('categories' = array)
			local(categories) = .payload->get('categories')
			with i in .categories do => {
				#categories->insert(#i)
			}
		}
		
		// SEND_AT
		if(.send_at) => {
			.payload->insert('send_at' = date(.send_at)->asinteger)
		}
		
		// ATTACHMENTS
		if(.attachments->size) => {
			.payload->insert('attachments' = array)
			local(attachments) = .payload->get('attachments')
			with i in .attachments do => {
				if(#i->isa(::string)) => {
					local(f) = file(#i)
					#attachments->insert(map(
						'filename'	= #f->name,
						'content'	= encode_base64(#f->readbytes)
					))
				else(#i->isa(::pair))
					#attachments->insert(map(
						'filename'	= #i->first,
						'content'	= encode_base64(#i->second)
					))
				}
			}
		}

	}
	
	private send() => debug => {

		local(request, response)

		debug('prepare request') => {
			#request = http_request(.apiurl)
			#request->headers->insert('Authorization'='Bearer ' + .apikey)
			#request->headers->insert('Content-Type'='application/json')
			debug(.payload)
			#request->postParams	= json_serialize(.payload)
		}

		split_thread => {
			#response = #request->response

			if(#response->statuscode != 202) => {
				stdoutnl('[' + date + '] SendGrid Error ' + #response->statuscode + ': ' + #response->body + ' Subject: "' + .subject + '"')
			}
		}

	}

}

?>