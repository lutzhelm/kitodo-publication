<?php
namespace EWW\Dpf\Controller;

/*
 * This file is part of the TYPO3 CMS project.
 *
 * It is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, either version 2
 * of the License, or any later version.
 *
 * For the full copyright and license information, please read the
 * LICENSE.txt file that was distributed with this source code.
 *
 * The TYPO3 project - inspiring people to share!
 */

/**
 * API to return METS dissemination and Attachments from Fedora.
 * Also renders METS XML for preview. Structure of the URIs totally
 * depend on proper RealURL configuration.
 *
 * Example:
 *
 * 1. METS from Fedora
 *   http://localhost/api/qucosa:1234/mets/
 *
 *   This always returns METS which is supplemented with additional information.
 *   The embedded MODS record is not the original MODS as it is stored in the
 *   repository datastream.
 *
 * 2. Attachment from Fedora
 *   http://localhost/api/qucosa:1234/attachment/ATT-0/
 *
 * 3. METS from Kitodo.Publication (this extension)
 *   http://localhost/api/3/preview/
 *
 * 4. DataCite from Kitodo.Publication (this extension)
 *
 * @author    Alexander Bigga <alexander.bigga@slub-dresden.de>
 * @author    Ralf Claussnitzer <ralf.claussnitzer@slub-dresden.de>
 * @author    Florian Rügamer <florian.ruegamer@slub-dresden.de>
 */

use TYPO3\CMS\Core\Utility\GeneralUtility;

/**
 * GetFileController
 */
class GetFileController extends \EWW\Dpf\Controller\AbstractController
{

    /**
     * documentRepository
     *
     * @var \EWW\Dpf\Domain\Repository\DocumentRepository
     * @inject
     */
    protected $documentRepository;

    /**
     * clientConfigurationManager
     *
     * @var \EWW\Dpf\Configuration\ClientConfigurationManager
     * @inject
     */
    protected $clientConfigurationManager;

    public function attachmentAction()
    {

        $piVars = GeneralUtility::_GP('tx_dpf'); // get GET params from powermail

        $fedoraHost = $this->clientConfigurationManager->getFedoraHost();

        switch ($piVars['action']) {
            case 'mets':
                $path = rtrim('http://' . $fedoraHost,"/").'/fedora/objects/'.$piVars['qid'].'/methods/qucosa:SDef/getMETSDissemination?supplement=yes';
                break;

            case 'preview':

                $document = $this->documentRepository->findByUid($piVars['qid']);

                if ($document) {

                    $metsXml = $this->buildMetsXml($document);
                    $this->response->setHeader('Content-Type', 'text/xml; charset=UTF-8');
                    return $metsXml;

                } else {

                    $this->response->setStatus(404);
                    return 'No such document';

                }

            case 'attachment':

                $qid = $piVars['qid'];

                $attachment = $piVars['attachment'];

                if (is_numeric($piVars['qid'])) {

                    // qid is local uid
                    $document = $this->documentRepository->findByUid($piVars['qid']);

                    $files = $document->getCurrentFileData();

                    foreach ($files['download'] as $id => $file) {

                        if ($file['id'] == $attachment) {

                            $path = $file['path'];

                            $contentType = $file['type'];

                            break;

                        }
                    }

                } else {

                    $path = rtrim('http://' . $fedoraHost, "/") . '/fedora/objects/' . $qid . '/datastreams/' . $attachment . '/content';

                }

                if (empty($path)) {
                    $this->response->setStatus(404);
                    return 'No file found';
                }

                break;

            case 'dataCite':

                $qid = $piVars['qid'];
                $source = explode(':', $qid);
                if($source[0] == 'qucosa') {

                    $path = rtrim('http://' . $fedoraHost,"/").'/fedora/objects/'.$piVars['qid'].'/methods/qucosa:SDef/getMETSDissemination?supplement=yes';
                    $metsXml = str_replace('&', '&amp;', file_get_contents($path));
                    $dataCiteXml = \EWW\Dpf\Helper\DataCiteXml::convertFromMetsXml($metsXml);

                } elseif($document = $this->documentRepository->findByUid($piVars['qid'])) {

                    $metsXml = str_replace('&', '&amp;', $this->buildMetsXml($document));
                    $dataCiteXml = \EWW\Dpf\Helper\DataCiteXml::convertFromMetsXml($metsXml);

                } else {

                    $this->response->setStatus(404);
                    return 'No such document';

                }
                $dom = new \DOMDocument('1.0', 'UTF-8');
                $dom->loadXML($dataCiteXml);
                $title = $dom->getElementsByTagName('title')[0];

                $this->response->setHeader('Content-Disposition', 'attachment; filename="' . self::sanitizeFilename($title->nodeValue) . '.DataCite.xml"');
                $this->response->setHeader('Content-Type', 'text/xml; charset=UTF-8');
                return $dataCiteXml;

                break;

            default:

                $this->response->setStatus(404);

                return 'No such action';
        }

        // get remote header and set it before passtrough
        $headers = get_headers($path);

        if (FALSE === $headers) {
            $this->response->setStatus(500);
            return 'Error while fetching headers';
        }

        $contentDispFlag = false;
        $contentTypeFlag = false;

        foreach ($headers as $value) {

            if (FALSE !== stripos($value, 'Content-Disposition')) {
                header($value);
                $contentDispFlag = true;
                continue;
            }

            if (FALSE !== stripos($value, 'Content-Type')) {
                header($value);
                $contentTypeFlag = true;
                continue;
            }

            if (FALSE !== stripos($value, 'Content-Length')) {
                header($value);
                continue;
            }
        }

        if (!$contentDispFlag) {
            header('Content-Disposition: attachment');
        }

        if (!$contentTypeFlag) {
            header('Content-Type: ' . $contentType);
        }

        if ($stream = fopen($path, 'r')) {

            // close active session if any
            session_write_close();

            // stop output buffering
            ob_end_clean();

            fpassthru($stream);

            fclose($stream);

            // Hard exit PHP script to avoid sending TYPO3 framework HTTP artifacts
            exit;

        } else {
            $this->response->setStatus(500);
            return 'Error while opening stream';
        }

    }

    private static function sanitizeFilename($filename)
    {
        // remove anything which isn't a word, whitespace, number or any of the following caracters -_~,;[]().
        $filename = mb_ereg_replace("([^\w\s\d\-_~,;\[\]\(\).])", '', $filename);
        // turn diacritical characters to ASCII
        setlocale(LC_ALL, 'en_US.utf8');
        $filename = iconv('utf-8', 'us-ascii//TRANSLIT', trim($filename));
        // replace whitespaces with underscore
        $filename = preg_replace('/\s+/', '_', $filename);

        return $filename;
    }

    private function buildMetsXml($document)
    {

        $exporter = new \EWW\Dpf\Services\MetsExporter();
        $fileData = $document->getCurrentFileData();
        $exporter->setFileData($fileData);
        $exporter->setMods($document->getXmlData());
        $exporter->setSlubInfo($document->getSlubInfoData());

        if (empty($document->getObjectIdentifier())) {

            $exporter->setObjId($document->getUid());

        } else {

            $exporter->setObjId($document->getObjectIdentifier());

        }

        $exporter->buildMets();
        $metsXml = $exporter->getMetsData();

        return $metsXml;
    }
}

