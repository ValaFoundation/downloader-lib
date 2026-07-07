namespace ValaFoundation.Downloader {
    public class Manager : Object {
        // Limit rychlosti v bajtech za sekundu (0 = bez limitu)
        public int64 speed_limit_bps { get; set; default = 0; }

        private int64 multiplier { get; set; default = 1; }

        private Soup.Session session;

        public Manager () {
            this.session = new Soup.Session ();
            this.session.user_agent = "Vala-Downloader/1.0";
        }

        public void set_speed_limit_in_bytes (int64 bytes_per_second) {
            this.speed_limit_bps = bytes_per_second;
        }

        public void set_speed_limit_in_kilobytes (int64 kilobytes_per_second) {
            this.speed_limit_bps = kilobytes_per_second * ValaFoundation.Downloader.KILOBYTE;
        }

        public void set_speed_limit_in_megabytes (int64 megabytes_per_second) {
            this.speed_limit_bps = megabytes_per_second * ValaFoundation.Downloader.MEGABYTE;
        }

        public void set_speed_limit_in_gigabytes (int64 gigabytes_per_second) {
            this.speed_limit_bps = gigabytes_per_second * ValaFoundation.Downloader.GIGABYTE;
        }

        private Result build_result (Soup.Message message, int64 total_bytes, int64 start_time_us, int64 content_length) {
            var result = new Result ();
            result.status_code = message.status_code;
            result.is_downloaded = message.status_code == Soup.Status.OK;

            int64 elapsed_us = GLib.get_monotonic_time () - start_time_us;
            if (elapsed_us > 0 && total_bytes > 0) {
                result.actual_speed_bps = (total_bytes * 1000000) / elapsed_us;
            }

            if (result.is_downloaded || (content_length > 0 && total_bytes >= content_length)) {
                result.remaining_time = 0;
            } else if (content_length > 0 && result.actual_speed_bps > 0 && total_bytes < content_length) {
                int64 remaining_bytes = content_length - total_bytes;
                result.remaining_time = (remaining_bytes + result.actual_speed_bps - 1) / result.actual_speed_bps;
            } else {
                result.remaining_time = -1;
            }

            return result;
        }

        public Result download (string url, string dest_path) throws GLib.Error {
            var file = File.new_for_path (dest_path);

            if (file.query_exists ()) {
                file.delete ();
            }

            var message = new Soup.Message ("GET", url);
            var input_stream = this.session.send (message, null);
            var output_stream = file.create (FileCreateFlags.REPLACE_DESTINATION, null);

            uint8 buffer[8192];
            int64 bytes_in_current_second = 0;
            int64 second_start_time = GLib.get_monotonic_time ();
            int64 start_time = second_start_time;
            int64 total_bytes = 0;
            int64 content_length = message.response_headers.get_content_length ();

            while (true) {
                ssize_t bytes_read = input_stream.read (buffer, null);
                if (bytes_read == 0) {
                    break;
                }

                total_bytes += bytes_read;

                size_t bytes_written;
                output_stream.write_all (buffer[0:bytes_read], out bytes_written, null);

                if (this.speed_limit_bps > 0) {
                    bytes_in_current_second += bytes_read;
                    int64 current_time = GLib.get_monotonic_time ();
                    int64 elapsed_us = current_time - second_start_time;
                    int64 expected_us = (bytes_in_current_second * 1000000) / this.speed_limit_bps;

                    if (elapsed_us < expected_us) {
                        GLib.Thread.usleep ((ulong) (expected_us - elapsed_us));
                    }

                    if (GLib.get_monotonic_time () - second_start_time >= 1000000) {
                        bytes_in_current_second = 0;
                        second_start_time = GLib.get_monotonic_time ();
                    }
                }
            }

            input_stream.close (null);
            output_stream.close (null);

            return build_result (message, total_bytes, start_time, content_length);
        }

        public async Result download_async (string url, string dest_path) throws GLib.Error {
            var file = File.new_for_path (dest_path);

            if (file.query_exists ()) {
                file.delete ();
            }

            var message = new Soup.Message ("GET", url);
            var input_stream = yield this.session.send_async (message, Priority.DEFAULT, null);
            var output_stream = yield file.create_async (FileCreateFlags.REPLACE_DESTINATION, Priority.DEFAULT, null);

            uint8 buffer[8192];
            int64 bytes_in_current_second = 0;
            int64 second_start_time = GLib.get_monotonic_time ();
            int64 start_time = second_start_time;
            int64 total_bytes = 0;
            int64 content_length = message.response_headers.get_content_length ();

            while (true) {
                ssize_t bytes_read = yield input_stream.read_async (buffer, Priority.DEFAULT, null);
                if (bytes_read == 0) break;

                total_bytes += bytes_read;

                size_t bytes_written;
                yield output_stream.write_all_async (buffer[0:bytes_read], Priority.DEFAULT, null, out bytes_written);

                if (this.speed_limit_bps > 0) {
                    bytes_in_current_second += bytes_read;
                    int64 current_time = GLib.get_monotonic_time ();
                    int64 elapsed_us = current_time - second_start_time;
                    int64 expected_us = (bytes_in_current_second * 1000000) / this.speed_limit_bps;

                    if (elapsed_us < expected_us) {
                        uint delay_ms = (uint) ((expected_us - elapsed_us) / 1000);
                        if (delay_ms > 0) {
                            yield async_sleep (delay_ms);
                        }
                    }

                    if (GLib.get_monotonic_time () - second_start_time >= 1000000) {
                        bytes_in_current_second = 0;
                        second_start_time = GLib.get_monotonic_time ();
                    }
                }
            }

            yield input_stream.close_async (Priority.DEFAULT, null);
            yield output_stream.close_async (Priority.DEFAULT, null);

            return build_result (message, total_bytes, start_time, content_length);
        }
    }
}
