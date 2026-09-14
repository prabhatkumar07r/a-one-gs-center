namespace :ebooks do

  desc "Migrate legacy Ebook PDF attachments"

  task migrate_legacy_pdfs: :environment do

    Ebook.find_each do |ebook|

      next unless ebook.pdf_file.attached?

      next if ebook.ebook_files.exists?

      ebook_file =
        ebook.ebook_files.create!(
          title: ebook.title,
          description: "Legacy E-Book PDF",
          position: 1,
          status: "active"
        )

      ebook_file.pdf.attach(
        ebook.pdf_file.blob
      )

      puts "Migrated Ebook ##{ebook.id}"

    rescue StandardError => e

      puts(
        "FAILED Ebook ##{ebook.id}: " \
        "#{e.class} - #{e.message}"
      )

    end

  end

end