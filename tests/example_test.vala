namespace AppTests {
    using GLib;
    using ValaFoundation.Downloader;
    using ValaFoundation.Testcases;

    public class ExampleTest : BaseTest {
        construct {
            add_test ("manager/default_speed_limit", test_manager_default_speed_limit);
            add_test ("manager/set_speed_limit_bytes", test_manager_set_speed_limit_bytes);
            add_test ("manager/set_speed_limit_kilobytes", test_manager_set_speed_limit_kilobytes);
            add_test ("manager/set_speed_limit_megabytes", test_manager_set_speed_limit_megabytes);
            add_test ("manager/set_speed_limit_gigabytes", test_manager_set_speed_limit_gigabytes);
            add_test ("manager/download_async_local_server", test_manager_download_async_local_server);
            add_test ("manager/download_sync_local_server", test_manager_download_sync_local_server);
            add_test ("manager/download_queue_sync_mixed_results", test_manager_download_queue_sync_mixed_results);
            add_test ("manager/download_queue_async_mixed_results", test_manager_download_queue_async_mixed_results);
            add_test ("manager/download_sync_not_found_result_state", test_manager_download_sync_not_found_result_state);
            add_test ("manager/download_sync_internal_error_unknown_length_result_state", test_manager_download_sync_internal_error_unknown_length_result_state);
        }

        public void test_manager_default_speed_limit () {
            var manager = new Manager ();
            assert (manager.speed_limit_bps == 0);
        }

        public void test_manager_set_speed_limit_bytes () {
            var manager = new Manager ();
            manager.set_speed_limit_in_bytes (2048);
            assert (manager.speed_limit_bps == 2048);
        }

        public void test_manager_set_speed_limit_kilobytes () {
            var manager = new Manager ();
            manager.set_speed_limit_in_kilobytes (2);
            assert (manager.speed_limit_bps == 2 * 1024);
        }

        public void test_manager_set_speed_limit_megabytes () {
            var manager = new Manager ();
            manager.set_speed_limit_in_megabytes (3);
            assert (manager.speed_limit_bps == 3 * 1024 * 1024);
        }

        public void test_manager_set_speed_limit_gigabytes () {
            var manager = new Manager ();
            manager.set_speed_limit_in_gigabytes (1);
            assert (manager.speed_limit_bps == 1024 * 1024 * 1024);
        }

        public void test_manager_download_async_local_server () {
            var server = new Soup.Server ("server-header", "ValaTestServer", null);
            string expected = "Downloader integration payload";
            uint8[] response_body = expected.data;

            server.add_handler (null, (srv, msg, path, query) => {
                msg.set_status (Soup.Status.OK, null);
                msg.set_response ("text/plain", Soup.MemoryUse.COPY, response_body);
            });

            try {
                assert (server.listen_local (0, Soup.ServerListenOptions.IPV4_ONLY));
            } catch (Error e) {
                assert_not_reached ();
            }

            var uris = server.get_uris ();
            string base_uri = uris.nth_data (0).to_string ();
            string url = base_uri.has_suffix ("/") ? @"$(base_uri)download" : @"$(base_uri)/download";

            string temp_dir;
            try {
                temp_dir = DirUtils.make_tmp ("vala-downloader-lib-test-XXXXXX");
            } catch (FileError e) {
                assert_not_reached ();
            }

            string dest_path = Path.build_filename (temp_dir, "downloaded.txt");
            var manager = new Manager ();
            var loop = new MainLoop (null, false);
            Result? result = null;
            Error? err = null;

            manager.download_async.begin (url, dest_path, (obj, res) => {
                try {
                    result = manager.download_async.end (res);
                } catch (Error e) {
                    err = e;
                }
                loop.quit ();
            });

            loop.run ();

            assert (err == null);
            assert (result != null);
            assert (result.is_downloaded);
            assert (result.status_code == Soup.Status.OK);
            assert (result.remaining_time == 0);
            assert (result.actual_speed_bps > 0);

            string downloaded;
            try {
                FileUtils.get_contents (dest_path, out downloaded);
            } catch (FileError e) {
                assert_not_reached ();
            }

            assert (downloaded == expected);

            FileUtils.remove (dest_path);
            DirUtils.remove (temp_dir);
            server.disconnect ();
        }

        public void test_manager_download_sync_local_server () {
            var server = new Soup.Server ("server-header", "ValaTestServer", null);
            string expected = "Downloader sync payload";
            uint8[] response_body = expected.data;

            server.add_handler (null, (srv, msg, path, query) => {
                msg.set_status (Soup.Status.OK, null);
                msg.set_response ("text/plain", Soup.MemoryUse.COPY, response_body);
            });

            try {
                assert (server.listen_local (0, Soup.ServerListenOptions.IPV4_ONLY));
            } catch (Error e) {
                assert_not_reached ();
            }

            var uris = server.get_uris ();
            string base_uri = uris.nth_data (0).to_string ();
            string url = base_uri.has_suffix ("/") ? @"$(base_uri)download-sync" : @"$(base_uri)/download-sync";

            string temp_dir;
            try {
                temp_dir = DirUtils.make_tmp ("vala-downloader-lib-test-XXXXXX");
            } catch (FileError e) {
                assert_not_reached ();
            }

            string dest_path = Path.build_filename (temp_dir, "downloaded-sync.txt");
            var manager = new Manager ();
            var loop = new MainLoop (null, false);

            Result? result = null;
            Error? err = null;

            var download_thread = new Thread<bool> ("sync-download", () => {
                try {
                    result = manager.download (url, dest_path);
                } catch (Error e) {
                    err = e;
                }

                Idle.add (() => {
                    loop.quit ();
                    return false;
                });

                return true;
            });

            loop.run ();
            download_thread.join ();

            assert (err == null);
            assert (result != null);

            assert (result.is_downloaded);
            assert (result.status_code == Soup.Status.OK);
            assert (result.remaining_time == 0);
            assert (result.actual_speed_bps > 0);

            string downloaded;
            try {
                FileUtils.get_contents (dest_path, out downloaded);
            } catch (FileError e) {
                assert_not_reached ();
            }

            assert (downloaded == expected);

            FileUtils.remove (dest_path);
            DirUtils.remove (temp_dir);
            server.disconnect ();
        }

        public void test_manager_download_sync_not_found_result_state () {
            var server = new Soup.Server ("server-header", "ValaTestServer", null);
            string response = "Not found payload";
            uint8[] response_body = response.data;

            server.add_handler (null, (srv, msg, path, query) => {
                msg.set_status (Soup.Status.NOT_FOUND, null);
                msg.set_response ("text/plain", Soup.MemoryUse.COPY, response_body);
            });

            try {
                assert (server.listen_local (0, Soup.ServerListenOptions.IPV4_ONLY));
            } catch (Error e) {
                assert_not_reached ();
            }

            var uris = server.get_uris ();
            string base_uri = uris.nth_data (0).to_string ();
            string url = base_uri.has_suffix ("/") ? @"$(base_uri)not-found" : @"$(base_uri)/not-found";

            string temp_dir;
            try {
                temp_dir = DirUtils.make_tmp ("vala-downloader-lib-test-XXXXXX");
            } catch (FileError e) {
                assert_not_reached ();
            }

            string dest_path = Path.build_filename (temp_dir, "downloaded-not-found.txt");
            var manager = new Manager ();
            var loop = new MainLoop (null, false);

            Result? result = null;
            Error? err = null;

            var download_thread = new Thread<bool> ("sync-download-not-found", () => {
                try {
                    result = manager.download (url, dest_path);
                } catch (Error e) {
                    err = e;
                }

                Idle.add (() => {
                    loop.quit ();
                    return false;
                });

                return true;
            });

            loop.run ();
            download_thread.join ();

            assert (err == null);
            assert (result != null);
            assert (!result.is_downloaded);
            assert (result.status_code == Soup.Status.NOT_FOUND);
            assert (result.remaining_time == -1);
            assert (result.actual_speed_bps > 0);

            FileUtils.remove (dest_path);
            DirUtils.remove (temp_dir);
            server.disconnect ();
        }

        public void test_manager_download_queue_sync_mixed_results () {
            var server = new Soup.Server ("server-header", "ValaTestServer", null);
            string ok_payload = "Downloader batch sync payload";
            uint8[] ok_response_body = ok_payload.data;

            server.add_handler (null, (srv, msg, path, query) => {
                if (path == "/ok-sync") {
                    msg.set_status (Soup.Status.OK, null);
                    msg.set_response ("text/plain", Soup.MemoryUse.COPY, ok_response_body);
                } else {
                    msg.set_status (Soup.Status.NOT_FOUND, null);
                }
            });

            try {
                assert (server.listen_local (0, Soup.ServerListenOptions.IPV4_ONLY));
            } catch (Error e) {
                assert_not_reached ();
            }

            var uris = server.get_uris ();
            string base_uri = uris.nth_data (0).to_string ();

            string temp_dir;
            try {
                temp_dir = DirUtils.make_tmp ("vala-downloader-lib-test-XXXXXX");
            } catch (FileError e) {
                assert_not_reached ();
            }

            string ok_url = base_uri.has_suffix ("/") ? @"$(base_uri)ok-sync" : @"$(base_uri)/ok-sync";
            string missing_url = base_uri.has_suffix ("/") ? @"$(base_uri)missing-sync" : @"$(base_uri)/missing-sync";

            string ok_dest_path = Path.build_filename (temp_dir, "downloaded-batch-sync-ok.txt");
            string missing_dest_path = Path.build_filename (temp_dir, "downloaded-batch-sync-missing.txt");

            var manager = new Manager ();
            manager.add_to_download (ok_url, ok_dest_path);
            manager.add_to_download (missing_url, missing_dest_path);

            var loop = new MainLoop (null, false);
            Gee.ArrayList<BatchDownloadResult>? results = null;

            var download_thread = new Thread<bool> ("sync-download-queue", () => {
                results = manager.download_queued ();

                Idle.add (() => {
                    loop.quit ();
                    return false;
                });

                return true;
            });

            loop.run ();
            download_thread.join ();

            assert (results != null);
            assert (results.size == 2);

            var ok_result = results[0];
            assert (ok_result.error_message == null);
            assert (ok_result.result != null);
            assert (ok_result.result.is_downloaded);
            assert (ok_result.result.status_code == Soup.Status.OK);

            var missing_result = results[1];
            assert (missing_result.error_message == null);
            assert (missing_result.result != null);
            assert (!missing_result.result.is_downloaded);
            assert (missing_result.result.status_code == Soup.Status.NOT_FOUND);

            string downloaded;
            try {
                FileUtils.get_contents (ok_dest_path, out downloaded);
            } catch (FileError e) {
                assert_not_reached ();
            }

            assert (downloaded == ok_payload);

            FileUtils.remove (ok_dest_path);
            FileUtils.remove (missing_dest_path);
            DirUtils.remove (temp_dir);
            server.disconnect ();
        }

        public void test_manager_download_queue_async_mixed_results () {
            var server = new Soup.Server ("server-header", "ValaTestServer", null);
            string ok_payload = "Downloader batch async payload";
            uint8[] ok_response_body = ok_payload.data;

            server.add_handler (null, (srv, msg, path, query) => {
                if (path == "/ok-async") {
                    msg.set_status (Soup.Status.OK, null);
                    msg.set_response ("text/plain", Soup.MemoryUse.COPY, ok_response_body);
                } else {
                    msg.set_status (Soup.Status.NOT_FOUND, null);
                }
            });

            try {
                assert (server.listen_local (0, Soup.ServerListenOptions.IPV4_ONLY));
            } catch (Error e) {
                assert_not_reached ();
            }

            var uris = server.get_uris ();
            string base_uri = uris.nth_data (0).to_string ();

            string temp_dir;
            try {
                temp_dir = DirUtils.make_tmp ("vala-downloader-lib-test-XXXXXX");
            } catch (FileError e) {
                assert_not_reached ();
            }

            string ok_url = base_uri.has_suffix ("/") ? @"$(base_uri)ok-async" : @"$(base_uri)/ok-async";
            string missing_url = base_uri.has_suffix ("/") ? @"$(base_uri)missing-async" : @"$(base_uri)/missing-async";

            string ok_dest_path = Path.build_filename (temp_dir, "downloaded-batch-async-ok.txt");
            string missing_dest_path = Path.build_filename (temp_dir, "downloaded-batch-async-missing.txt");

            var manager = new Manager ();
            manager.add_to_download (ok_url, ok_dest_path);
            manager.add_to_download (missing_url, missing_dest_path);

            var loop = new MainLoop (null, false);

            Gee.ArrayList<BatchDownloadResult>? results = null;

            manager.download_queued_async.begin (true, (obj, res) => {
                results = manager.download_queued_async.end (res);
                loop.quit ();
            });

            loop.run ();

            assert (results != null);
            assert (results.size == 2);

            var ok_result = results[0];
            assert (ok_result.error_message == null);
            assert (ok_result.result != null);
            assert (ok_result.result.is_downloaded);
            assert (ok_result.result.status_code == Soup.Status.OK);

            var missing_result = results[1];
            assert (missing_result.error_message == null);
            assert (missing_result.result != null);
            assert (!missing_result.result.is_downloaded);
            assert (missing_result.result.status_code == Soup.Status.NOT_FOUND);

            string downloaded;
            try {
                FileUtils.get_contents (ok_dest_path, out downloaded);
            } catch (FileError e) {
                assert_not_reached ();
            }

            assert (downloaded == ok_payload);

            FileUtils.remove (ok_dest_path);
            FileUtils.remove (missing_dest_path);
            DirUtils.remove (temp_dir);
            server.disconnect ();
        }

        public void test_manager_download_sync_internal_error_unknown_length_result_state () {
            var server = new Soup.Server ("server-header", "ValaTestServer", null);

            server.add_handler (null, (srv, msg, path, query) => {
                msg.set_status (Soup.Status.INTERNAL_SERVER_ERROR, null);
            });

            try {
                assert (server.listen_local (0, Soup.ServerListenOptions.IPV4_ONLY));
            } catch (Error e) {
                assert_not_reached ();
            }

            var uris = server.get_uris ();
            string base_uri = uris.nth_data (0).to_string ();
            string url = base_uri.has_suffix ("/") ? @"$(base_uri)server-error" : @"$(base_uri)/server-error";

            string temp_dir;
            try {
                temp_dir = DirUtils.make_tmp ("vala-downloader-lib-test-XXXXXX");
            } catch (FileError e) {
                assert_not_reached ();
            }

            string dest_path = Path.build_filename (temp_dir, "downloaded-server-error.txt");
            var manager = new Manager ();
            var loop = new MainLoop (null, false);

            Result? result = null;
            Error? err = null;

            var download_thread = new Thread<bool> ("sync-download-server-error", () => {
                try {
                    result = manager.download (url, dest_path);
                } catch (Error e) {
                    err = e;
                }

                Idle.add (() => {
                    loop.quit ();
                    return false;
                });

                return true;
            });

            loop.run ();
            download_thread.join ();

            assert (err == null);
            assert (result != null);
            assert (!result.is_downloaded);
            assert (result.status_code == Soup.Status.INTERNAL_SERVER_ERROR);
            assert (result.actual_speed_bps == 0);
            assert (result.remaining_time == -1);

            FileUtils.remove (dest_path);
            DirUtils.remove (temp_dir);
            server.disconnect ();
        }

    }
}

