# volume registration
type = "csi"
id = "${aws_ebs_volume_name}"
name = "${aws_ebs_volume_name}"
external_id = "${aws_ebs_volume_id}"
access_mode = "single-node-writer"
attachment_mode = "file-system"
plugin_id = "${csi_plugin_id}"
