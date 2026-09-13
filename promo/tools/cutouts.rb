require 'json'
require 'digest'
root = File.expand_path('../qa/native', __dir__)
data = JSON.parse(File.read(File.expand_path('../docs/native-layout-source.json', __dir__)))
data['captures'] = JSON.parse(File.read(root + '/layout-native.json'))['captures']
data['captures'].each do |r|
  r['path'] = File.join(root, r['name'] + '.png')
  r['sha256'] = Digest::SHA256.file(r['path']).hexdigest
end
data['cutouts'].each do |cut|
  cut['path'] = File.join(root, cut['source'] + '--' + cut['role'] + '.png')
  x, y, width, height = cut['box'].map { |n| n * data['scale'] }
  abort 'Native cutout failed' unless system('magick', root + '/' + cut['source'] + '.png', '-crop', "#{width}x#{height}+#{x}+#{y}", '+repage', cut['path'])
  cut['sha256'] = Digest::SHA256.file(cut['path']).hexdigest
end
File.write(root + '/layout.json', JSON.pretty_generate(data) + "\n")
puts "Verified #{data['captures'].length} native captures and #{data['cutouts'].length} cutouts."
