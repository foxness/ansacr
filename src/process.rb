require 'date'
require 'json'

VISA_END = '1234'

def get_unprocessed_filepath
    rootdir = File.dirname(File.expand_path(File.dirname(__FILE__)))
    unprocessed_dir = File.join(rootdir, 'data', 'unprocessed')
	Dir[File.join unprocessed_dir, '*'].first
end

def parse_smses(raw_file)
    sms_regex = /<sms protocol="(?<protocol>[^"]+)" address="(?<address>[^"]+)" date="(?<date>[^"]+)" type="(?<type>[^"]+)" subject="(?<subject>[^"]+)" body=(?<body>('[^']*')|("[^"]*")) toa="(?<toa>[^"]+)" sc_toa="(?<sc_toa>[^"]+)" service_center="(?<service_center>[^"]+)" read="(?<read>[^"]+)" status="(?<status>[^"]+)" locked="(?<locked>[^"]+)" date_sent="(?<date_sent>[^"]+)" sub_id="(?<sub_id>[^"]+)" readable_date="(?<readable_date>[^"]+)" contact_name="(?<contact_name>[^"]+)" \/>/
    
    sms_entry_count = raw_file.scan(/<sms /).length
    
    smses = raw_file.each_line.map { |a| sms_regex.match(a) }.compact.map { |a| a.named_captures }
    
    raise 'DISCREPANCY DETECTED' unless sms_entry_count == smses.length
    
    smses.each do |sms|
        sms['date'] = DateTime.strptime sms['date'], '%Q'
        sms['date_sent'] = DateTime.strptime sms['date_sent'], '%Q'
        sms['body'] = sms['body'][1...-1]
        sms['type'] = case sms['type']
            when '1'
                'received'
            when '2'
                'sent'
            when '3'
                'draft'
            end
    end

    smses
end

def get_transactions(smses, visa_end)
    unprocessed_transactions = smses.select { |a| a['address'] == '900' && a['body'].start_with?("VISA#{visa_end} ") }
    body_regex =  /^.{4}(?<visa>.{4}).(?<date>.{8} )?(?:(?<time>\d{2}:\d{2}) )?.+Баланс: (?<balance>\d+(?:.\d+)?)[[:alpha:]]+$/
    transactions = []
    unprocessed_transactions.each do |unprocessed_transaction|
        match = body_regex.match unprocessed_transaction['body']

        unless match
            raise 'FOUND A NON-MATCHING BODY' unless unprocessed_transaction['body'].include? 'ОТКАЗ'
            next
        end

        transaction = Hash.new

        transaction['date_received'] = unprocessed_transaction['date']
        transaction['date_sent'] = unprocessed_transaction['date_sent']
        transaction['body'] = unprocessed_transaction['body']

        transaction['reported_date'] = transaction['date_received']
        transaction['balance'] = match.named_captures['balance'].to_f

        transactions << transaction
    end

    transactions
end

def get_processed_filepath(unprocessed_filepath)
    File.join(File.dirname(File.dirname(unprocessed_filepath)), 'processed', File.basename(unprocessed_filepath, '.xml') + '.json')
end

def create_processed_directory(processed_filepath)
    directory = File.dirname processed_filepath
    Dir.mkdir(directory) unless File.exists?(directory)
end

def main
    filepath = get_unprocessed_filepath
    raw = File.read filepath
    smses = parse_smses raw
    transactions = get_transactions smses, VISA_END
    serialized = transactions.to_json
    processed_filepath = get_processed_filepath filepath
	create_processed_directory processed_filepath
    File.write processed_filepath, serialized
end

main